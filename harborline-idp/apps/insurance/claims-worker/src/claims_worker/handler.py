"""Message handling: CloudEvent parsing, idempotency, triage, persistence, settlement decision.

Delivery semantics: Service Bus is at-least-once and the publisher may re-send after a crash, so the handler
records each message id in processed_messages inside the same transaction as the state change.
"""

from __future__ import annotations

import datetime as dt
import json
import logging
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from enum import StrEnum
from typing import Any, Protocol

from .triage import ClaimContext, TriageDecision, triage

log = logging.getLogger(__name__)
CONSUMER = "claims-worker"
EXPECTED_TYPE = "com.harborline.claim.submitted"


class Disposition(StrEnum):
    COMPLETE = "complete"
    DEAD_LETTER = "dead_letter"
    ABANDON = "abandon"


@dataclass(frozen=True)
class InboundMessage:
    message_id: str
    body: bytes | str
    delivery_count: int = 1


@dataclass(frozen=True)
class Result:
    disposition: Disposition
    reason: str | None = None
    decision: TriageDecision | None = None


class PoisonMessageError(ValueError):
    """The message can never be processed; dead-letter it."""


class Store(Protocol):
    def transaction(self) -> Any: ...
    def mark_processed(self, tx: Any, message_id: str, consumer: str) -> bool: ...
    def load_claim(self, tx: Any, claim_id: str) -> dict[str, Any] | None: ...
    def save_triage(self, tx: Any, claim_id: str, decision: TriageDecision) -> None: ...


class TransientError(Exception):
    """Retryable infrastructure failure (DB unavailable, timeout)."""


def parse_event(msg: InboundMessage) -> dict[str, Any]:
    try:
        event = json.loads(msg.body)
    except (json.JSONDecodeError, TypeError) as exc:
        raise PoisonMessageError("body is not valid JSON") from exc
    if event.get("specversion") != "1.0" or event.get("type") != EXPECTED_TYPE:
        raise PoisonMessageError(f"unexpected event type {event.get('type')!r}")
    data = event.get("data") or {}
    for key in ("claim_id", "loss_type", "loss_date", "estimated_amount"):
        if key not in data:
            raise PoisonMessageError(f"missing data.{key}")
    try:
        dt.date.fromisoformat(data["loss_date"])
        Decimal(data["estimated_amount"])
    except (ValueError, InvalidOperation) as exc:
        raise PoisonMessageError("invalid data types") from exc
    return event


class ClaimHandler:
    def __init__(self, store: Store, *, today: dt.date | None = None) -> None:
        self.store = store
        self._today = today

    def handle(self, msg: InboundMessage) -> Result:
        try:
            event = parse_event(msg)
        except PoisonMessageError as exc:
            log.warning("dead-lettering poison message", extra={"message_id": msg.message_id, "reason": str(exc)})
            return Result(Disposition.DEAD_LETTER, str(exc))

        data = event["data"]
        try:
            with self.store.transaction() as tx:
                if not self.store.mark_processed(tx, msg.message_id, CONSUMER):
                    log.info("duplicate message ignored", extra={"message_id": msg.message_id})
                    return Result(Disposition.COMPLETE, "duplicate")
                claim = self.store.load_claim(tx, data["claim_id"])
                if claim is None:
                    raise PoisonMessageError("claim not found")
                ctx = ClaimContext(
                    claim_id=data["claim_id"],
                    loss_type=data["loss_type"],
                    loss_date=dt.date.fromisoformat(data["loss_date"]),
                    reported_on=self._today or claim["created_at"].date(),
                    estimated_amount=Decimal(data["estimated_amount"]),
                    policy_effective_date=claim["policy_effective_date"],
                    prior_claims_on_policy=int(claim.get("prior_claims_on_policy", 0)),
                )
                decision = triage(ctx)
                self.store.save_triage(tx, data["claim_id"], decision)
        except PoisonMessageError as exc:
            return Result(Disposition.DEAD_LETTER, str(exc))
        except TransientError as exc:
            log.warning(
                "transient failure; message will be retried",
                extra={"message_id": msg.message_id, "delivery_count": msg.delivery_count},
            )
            return Result(Disposition.ABANDON, type(exc).__name__)

        log.info(
            "claim triaged",
            extra={"claim_id": data["claim_id"], "outcome": decision.outcome.value, "score": decision.score},
        )
        return Result(Disposition.COMPLETE, decision=decision)
