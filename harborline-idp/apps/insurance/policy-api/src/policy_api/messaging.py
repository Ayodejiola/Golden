"""Service Bus publishing with CloudEvents 1.0 envelopes (ADR-0008).

Authentication uses workload identity (DefaultAzureCredential). The emulator connection string is accepted
only for local development (enforced in Settings.validate).
"""

from __future__ import annotations

import json
import logging
from typing import Any, Protocol

from .config import Settings

log = logging.getLogger(__name__)

TOPIC_BY_AGGREGATE = {"claim": "claims", "policy": "policies"}


class Publisher(Protocol):
    def publish(self, topic: str, events: list[dict[str, Any]]) -> None: ...
    def close(self) -> None: ...


def to_cloud_event(row: dict[str, Any]) -> dict[str, Any]:
    """Map an outbox row to a CloudEvent. The id is deterministic so Service Bus duplicate detection
    (10-minute window) makes re-publishing after a crash idempotent."""
    payload = row["payload"] if isinstance(row["payload"], dict) else json.loads(row["payload"])
    return {
        "specversion": "1.0",
        "id": f"{row['aggregate_type']}-{row['aggregate_id']}-{row['id']}",
        "source": "/harborline/insurance/policy-api",
        "type": f"com.harborline.{row['event_type']}",
        "subject": str(row["aggregate_id"]),
        "time": row["created_at"].isoformat() if hasattr(row["created_at"], "isoformat") else str(row["created_at"]),
        "datacontenttype": "application/json",
        "data": payload,
        "eventType": row["event_type"],  # mirrored to application properties for SQL filters
        "traceparent": row.get("traceparent"),
    }


class ServiceBusPublisher:
    def __init__(self, settings: Settings) -> None:
        from azure.servicebus import ServiceBusClient

        if settings.servicebus_connection_string:
            self._client = ServiceBusClient.from_connection_string(settings.servicebus_connection_string)
        else:
            from azure.identity import DefaultAzureCredential

            if not settings.servicebus_fqdn:
                raise RuntimeError("SERVICEBUS_FQDN is required")
            self._client = ServiceBusClient(settings.servicebus_fqdn, DefaultAzureCredential())
        self._senders: dict[str, Any] = {}

    def _sender(self, topic: str) -> Any:
        if topic not in self._senders:
            self._senders[topic] = self._client.get_topic_sender(topic_name=topic)
        return self._senders[topic]

    def publish(self, topic: str, events: list[dict[str, Any]]) -> None:
        from azure.servicebus import ServiceBusMessage

        sender = self._sender(topic)
        batch = sender.create_message_batch()
        for ev in events:
            props = {"eventType": ev["eventType"], "cloudEvents:type": ev["type"]}
            if ev.get("traceparent"):
                props["traceparent"] = ev["traceparent"]
            body = {k: v for k, v in ev.items() if k not in {"eventType", "traceparent"}}
            batch.add_message(
                ServiceBusMessage(
                    json.dumps(body),
                    message_id=ev["id"],
                    content_type="application/cloudevents+json",
                    subject=ev["type"],
                    application_properties=props,
                )
            )
        sender.send_messages(batch)

    def close(self) -> None:
        for s in self._senders.values():
            s.close()
        self._client.close()
