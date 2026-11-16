"""OpenTelemetry SDK setup (ADR-0009). Configuration comes from standard OTEL_* environment variables
set by the golden-service chart; this module only wires providers and defines business metrics."""

from __future__ import annotations

import logging
import os
from collections.abc import Callable, Iterable
from typing import Any

from opentelemetry import metrics, trace
from opentelemetry.metrics import CallbackOptions, Observation

log = logging.getLogger(__name__)
_meter = metrics.get_meter("policy_api", "0.1.0")

QUOTES_ISSUED = _meter.create_counter("insurance.quotes.issued", description="Quotes issued, by product and status")
POLICIES_BOUND = _meter.create_counter("insurance.policies.bound", description="Policies bound, by product")
CLAIMS_SUBMITTED = _meter.create_counter("insurance.claims.submitted", description="FNOL claims submitted")

tracer = trace.get_tracer("policy_api")


def setup_telemetry(app: Any | None = None) -> None:
    """Install SDK providers and auto-instrumentation. No-op when OTEL_SDK_DISABLED=true (unit tests)."""
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

    resource = Resource.create()  # reads OTEL_SERVICE_NAME + OTEL_RESOURCE_ATTRIBUTES
    tp = TracerProvider(resource=resource)
    tp.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(tp)
    metrics.set_meter_provider(
        MeterProvider(resource=resource, metric_readers=[PeriodicExportingMetricReader(OTLPMetricExporter())])
    )
    LoggingInstrumentor().instrument(set_logging_format=False)
    PsycopgInstrumentor().instrument(enable_commenter=False)  # never put SQL text with values in spans
    if app is not None:
        from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

        FastAPIInstrumentor.instrument_app(app, excluded_urls="healthz/.*")
    log.info("telemetry initialised")


def current_traceparent() -> str | None:
    """W3C traceparent of the active span, stored with outbox events for end-to-end traces."""
    ctx = trace.get_current_span().get_span_context()
    if not ctx.is_valid:
        return None
    return f"00-{ctx.trace_id:032x}-{ctx.span_id:016x}-{int(ctx.trace_flags):02x}"


def register_outbox_gauge(read_pending: Callable[[], int]) -> None:
    """Expose outbox backlog as insurance_outbox_pending (alerting: runbooks/outbox-backlog)."""

    def _observe(_: CallbackOptions) -> Iterable[Observation]:
        try:
            yield Observation(read_pending())
        except Exception:
            log.debug("outbox gauge read failed", exc_info=True)

    _meter.create_observable_gauge(
        "insurance.outbox.pending", callbacks=[_observe], description="Outbox events awaiting publish"
    )
