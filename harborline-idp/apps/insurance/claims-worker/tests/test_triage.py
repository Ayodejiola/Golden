from __future__ import annotations

import datetime as dt
from decimal import Decimal

from claims_worker.triage import ClaimContext, Outcome, triage

POLICY_START = dt.date(2026, 1, 1)


def ctx(**kw: object) -> ClaimContext:
    base = {
        "claim_id": "c1",
        "loss_type": "collision",
        "loss_date": dt.date(2026, 6, 1),
        "reported_on": dt.date(2026, 6, 2),
        "estimated_amount": Decimal("1200"),
        "policy_effective_date": POLICY_START,
        "prior_claims_on_policy": 0,
    }
    base.update(kw)
    return ClaimContext(**base)  # type: ignore[arg-type]


def test_small_routine_claim_fast_tracks() -> None:
    d = triage(ctx())
    assert d.outcome is Outcome.FAST_TRACK and d.score == 0 and d.reasons == []


def test_large_claim_goes_to_adjuster() -> None:
    d = triage(ctx(estimated_amount=Decimal("30000")))
    assert d.outcome is Outcome.ADJUSTER_REVIEW and d.score == 40


def test_early_large_theft_goes_to_siu() -> None:
    d = triage(
        ctx(
            loss_type="theft",
            estimated_amount=Decimal("30000"),
            loss_date=dt.date(2026, 1, 10),
            reported_on=dt.date(2026, 1, 11),
        )
    )
    assert d.outcome is Outcome.SIU_REVIEW
    assert d.score == 85
    assert any("inception" in r for r in d.reasons)


def test_late_reporting_adds_risk() -> None:
    d = triage(ctx(reported_on=dt.date(2026, 7, 15), estimated_amount=Decimal("6000")))
    assert d.score == 35 and d.outcome is Outcome.ADJUSTER_REVIEW


def test_score_is_capped() -> None:
    d = triage(
        ctx(
            loss_type="theft",
            estimated_amount=Decimal("90000"),
            loss_date=dt.date(2026, 1, 2),
            reported_on=dt.date(2026, 3, 30),
            prior_claims_on_policy=3,
        )
    )
    assert d.score == 100 and d.outcome is Outcome.SIU_REVIEW
