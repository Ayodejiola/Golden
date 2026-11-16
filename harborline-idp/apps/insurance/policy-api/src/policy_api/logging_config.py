"""Structured JSON logging with trace correlation and PII masking (ASVS V16)."""

from __future__ import annotations

import json
import logging
import sys
from datetime import UTC, datetime
from typing import Any

from .pii import mask

_RESERVED = set(logging.LogRecord("", 0, "", 0, "", None, None).__dict__) | {"message", "asctime"}


class JsonFormatter(logging.Formatter):
    def __init__(self, service: str, environment: str) -> None:
        super().__init__()
        self.service = service
        self.environment = environment

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": datetime.fromtimestamp(record.created, UTC).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": mask(record.getMessage()),
            "service.name": self.service,
            "deployment.environment.name": self.environment,
        }
        # Injected by opentelemetry-instrumentation-logging when tracing is active.
        for attr, key in (("otelTraceID", "trace_id"), ("otelSpanID", "span_id")):
            value = getattr(record, attr, None)
            if value and value != "0":
                payload[key] = value
        for key, value in record.__dict__.items():
            if key not in _RESERVED and not key.startswith("otel"):
                payload[key] = mask(value) if isinstance(value, str) else value
        if record.exc_info:
            payload["exception.type"] = record.exc_info[0].__name__ if record.exc_info[0] else None
            payload["exception.stacktrace"] = mask(self.formatException(record.exc_info))
        return json.dumps(payload, default=str)


def configure_logging(service: str, environment: str, level: str = "INFO") -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter(service, environment))
    root = logging.getLogger()
    root.handlers[:] = [handler]
    root.setLevel(level)
    for noisy in ("azure", "uvicorn.access", "urllib3"):
        logging.getLogger(noisy).setLevel(logging.WARNING)
