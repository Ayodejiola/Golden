from __future__ import annotations

import datetime as dt
import json
from contextlib import contextmanager
from typing import Any

from claims_worker.handler import ClaimHandler, Disposition, InboundMessage, TransientError
from claims_worker.triage import Outcome, TriageDecision


class FakeStore:
    def __init__(self, claims: dict[str, dict[str, Any]], fail: bool = False) -> None:
        self.claims = claims
        self.processed: set[str] = set()
        self.saved: dict[str, TriageDecision] = {}
        self.fail = fail

    @contextmanager
    def transaction(self):  # type: ignore[no-untyped-def]
        if self.fail:
            raise TransientError("db down")
        snapshot = (set(self.processed), dict(self.saved))
        try:
            yield self
        except Exception:
            self.processed, self.saved = snapshot  # rollback
            raise

    def mark_processed(self, tx: Any, message_id: str, consumer: str) -> bool:
        if message_id in self.processed:
            return False
        self.processed.add(message_id)
        return True

    def load_claim(self, tx: Any, claim_id: str) -> dict[str, Any] | None:
        return self.claims.get(claim_id)

    def save_triage(self, tx: Any, claim_id: str, decision: TriageDecision) -> None:
        self.saved[claim_id] = decision


def event(claim_id: str = "c-1", **data: Any) -> str:
    payload = {
        "claim_id": claim_id,
        "loss_type": "collision",
        "loss_date": "2026-06-01",
        "estimated_amount": "1500.00",
        **data,
    }
    return json.dumps({"specversion": "1.0", "type": "com.harborline.claim.submitted", "id": "x", "data": payload})


CLAIMS = {
    "c-1": {
        "created_at": dt.datetime(2026, 6, 2, tzinfo=dt.UTC),
        "policy_effective_date": dt.date(2026, 1, 1),
        "prior_claims_on_policy": 0,
    }
}


def test_happy_path_triages_and_completes() -> None:
    store = FakeStore(dict(CLAIMS))
    r = ClaimHandler(store).handle(InboundMessage("m1", event()))
    assert r.disposition is Disposition.COMPLETE
    assert store.saved["c-1"].outcome is Outcome.FAST_TRACK


def test_duplicate_delivery_is_idempotent() -> None:
    store = FakeStore(dict(CLAIMS))
    h = ClaimHandler(store)
    h.handle(InboundMessage("m1", event()))
    r = h.handle(InboundMessage("m1", event()))
    assert r.disposition is Disposition.COMPLETE and r.reason == "duplicate"


def test_poison_messages_are_dead_lettered() -> None:
    h = ClaimHandler(FakeStore(dict(CLAIMS)))
    assert h.handle(InboundMessage("m2", "not json")).disposition is Disposition.DEAD_LETTER
    wrong_type = json.dumps({"specversion": "1.0", "type": "com.harborline.other", "data": {}})
    assert h.handle(InboundMessage("m3", wrong_type)).disposition is Disposition.DEAD_LETTER
    assert h.handle(InboundMessage("m4", event(estimated_amount="lots"))).disposition is Disposition.DEAD_LETTER


def test_unknown_claim_dead_letters_and_rolls_back_inbox() -> None:
    store = FakeStore({})
    r = ClaimHandler(store).handle(InboundMessage("m5", event("missing")))
    assert r.disposition is Disposition.DEAD_LETTER
    assert "m5" not in store.processed


def test_transient_failure_abandons_for_retry() -> None:
    r = ClaimHandler(FakeStore(dict(CLAIMS), fail=True)).handle(InboundMessage("m6", event(), delivery_count=2))
    assert r.disposition is Disposition.ABANDON
