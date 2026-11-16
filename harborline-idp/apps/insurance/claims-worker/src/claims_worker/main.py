"""Worker entrypoint: Service Bus receive loop + liveness/readiness HTTP endpoints for Kubernetes probes."""

from __future__ import annotations

import json
import logging
import os
import signal
import sys
import threading
import time
from datetime import UTC, datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

from opentelemetry import metrics, trace
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator

from . import __version__
from .handler import ClaimHandler, Disposition, InboundMessage

log = logging.getLogger("claims_worker")
tracer = trace.get_tracer("claims_worker")
meter = metrics.get_meter("claims_worker", __version__)
TRIAGED = meter.create_counter("insurance.claims.triaged", description="Claims triaged by outcome")
TRIAGE_LATENCY = meter.create_histogram(
    "insurance.claim.triage.duration", unit="s", description="Time from claim event to triage decision"
)

STATE: dict[str, Any] = {"last_loop": time.monotonic(), "ready": False}
STOP = threading.Event()


class Probe(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path == "/healthz/live":
            ok = time.monotonic() - STATE["last_loop"] < 120  # receive loop is not wedged
        elif self.path == "/healthz/ready":
            ok = bool(STATE["ready"])
        else:
            self.send_response(404)
            self.end_headers()
            return
        self.send_response(200 if ok else 503)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"status": "ok" if ok else "unavailable"}).encode())

    def log_message(self, *args: Any) -> None:  # silence default stderr access log
        return


def configure_logging() -> None:
    class Json(logging.Formatter):
        def format(self, r: logging.LogRecord) -> str:
            base = {
                "timestamp": datetime.fromtimestamp(r.created, UTC).isoformat(),
                "level": r.levelname,
                "logger": r.name,
                "message": r.getMessage(),
                "service.name": "claims-worker",
            }
            for k in ("claim_id", "outcome", "score", "message_id", "reason", "delivery_count"):
                if hasattr(r, k):
                    base[k] = getattr(r, k)
            if getattr(r, "otelTraceID", "0") != "0":
                base["trace_id"] = r.otelTraceID
            return json.dumps(base, default=str)

    h = logging.StreamHandler(sys.stdout)
    h.setFormatter(Json())
    logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO").upper(), handlers=[h], force=True)
    logging.getLogger("azure").setLevel(logging.WARNING)


def setup_telemetry() -> None:
    if os.environ.get("OTEL_SDK_DISABLED", "false").lower() == "true":
        return
    from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
    from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
    from opentelemetry.instrumentation.logging import LoggingInstrumentor
    from opentelemetry.instrumentation.psycopg import PsycopgInstrumentor
    from opentelemetry.sdk.metrics import MeterProvider
    from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
    from opentelemetry.sdk.resources import Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor

    resource = Resource.create()
    tp = TracerProvider(resource=resource)
    tp.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(tp)
    metrics.set_meter_provider(
        MeterProvider(resource=resource, metric_readers=[PeriodicExportingMetricReader(OTLPMetricExporter())])
    )
    LoggingInstrumentor().instrument(set_logging_format=False)
    PsycopgInstrumentor().instrument(enable_commenter=False)


def service_bus_client() -> Any:
    from azure.servicebus import ServiceBusClient

    conn = os.environ.get("SERVICEBUS_CONNECTION_STRING")
    if conn:
        if os.environ.get("APP_ENVIRONMENT", "local") != "local":
            raise RuntimeError("SERVICEBUS_CONNECTION_STRING is only allowed locally")
        return ServiceBusClient.from_connection_string(conn)
    from azure.identity import DefaultAzureCredential

    return ServiceBusClient(os.environ["SERVICEBUS_FQDN"], DefaultAzureCredential())


def process(handler: ClaimHandler, receiver: Any, message: Any) -> None:
    props = {
        (k.decode() if isinstance(k, bytes) else k): (v.decode() if isinstance(v, bytes) else v)
        for k, v in (message.application_properties or {}).items()
    }
    ctx = TraceContextTextMapPropagator().extract({"traceparent": props.get("traceparent", "")})
    with tracer.start_as_current_span("claims.triage", context=ctx, kind=trace.SpanKind.CONSUMER) as span:
        span.set_attribute("messaging.system", "servicebus")
        span.set_attribute("messaging.message.id", str(message.message_id))
        body = b"".join(message.body) if not isinstance(message.body, (bytes, str)) else message.body
        result = handler.handle(InboundMessage(str(message.message_id), body, message.delivery_count or 1))
        span.set_attribute("insurance.claim.disposition", result.disposition.value)
        if result.disposition is Disposition.COMPLETE:
            receiver.complete_message(message)
            if result.decision:
                TRIAGED.add(1, {"outcome": result.decision.outcome.value})
                enqueued = message.enqueued_time_utc
                if enqueued:
                    TRIAGE_LATENCY.record((datetime.now(UTC) - enqueued).total_seconds())
        elif result.disposition is Disposition.DEAD_LETTER:
            receiver.dead_letter_message(message, reason="poison", error_description=(result.reason or "")[:1024])
        else:
            receiver.abandon_message(message)


def run() -> int:
    configure_logging()
    setup_telemetry()
    from .store import PostgresStore

    port = int(os.environ.get("PORT", "8080"))
    server = ThreadingHTTPServer(("0.0.0.0", port), Probe)  # noqa: S104 - pod network; NetworkPolicy applies
    threading.Thread(target=server.serve_forever, daemon=True, name="probes").start()

    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, lambda *_: STOP.set())

    store = PostgresStore()
    handler = ClaimHandler(store)
    batch = int(os.environ.get("MAX_CONCURRENCY", "4"))
    with (
        service_bus_client() as client,
        client.get_subscription_receiver(
            topic_name=os.environ.get("SERVICEBUS_TOPIC", "claims"),
            subscription_name=os.environ.get("SERVICEBUS_SUBSCRIPTION", "triage"),
            prefetch_count=batch * 2,
        ) as receiver,
    ):
        STATE["ready"] = True
        log.info("claims-worker started", extra={"reason": f"batch={batch}"})
        while not STOP.is_set():
            STATE["last_loop"] = time.monotonic()
            for message in receiver.receive_messages(max_message_count=batch, max_wait_time=5):
                process(handler, receiver, message)
    STATE["ready"] = False
    store.close()
    server.shutdown()
    log.info("claims-worker stopped")
    return 0


if __name__ == "__main__":
    sys.exit(run())
