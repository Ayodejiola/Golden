"""Claim triage rules (pure, deterministic, unit-tested).

Routes each first notice of loss to fast-track settlement, an adjuster, or the Special Investigations Unit (SIU).
Rules are illustrative for the reference application; a real insurer would externalise them to a rules engine
with model-risk governance.
"""

from __future__ import annotations

import datetime as dt
from dataclasses import dataclass, field
from decimal import Decimal
from enum import StrEnum


class Outcome(StrEnum):
    FAST_TRACK = "fast_track"
    ADJUSTER_REVIEW = "adjuster_review"
    SIU_REVIEW = "siu_review"


@dataclass(frozen=True)
class ClaimContext:
    claim_id: str
    loss_type: str
    loss_date: dt.date
    reported_on: dt.date
    estimated_amount: Decimal
    policy_effective_date: dt.date
    prior_claims_on_policy: int = 0


@dataclass(frozen=True)
class TriageDecision:
    score: int
    outcome: Outcome
    reasons: list[str] = field(default_factory=list)


SIU_THRESHOLD = 60
ADJUSTER_THRESHOLD = 30


def triage(ctx: ClaimContext) -> TriageDecision:
    score = 0
    reasons: list[str] = []

    if ctx.estimated_amount >= Decimal("25000"):
        score += 40
        reasons.append("high estimated amount (>= $25,000)")
    elif ctx.estimated_amount >= Decimal("5000"):
        score += 15
        reasons.append("moderate estimated amount (>= $5,000)")

    days_into_policy = (ctx.loss_date - ctx.policy_effective_date).days
    if 0 <= days_into_policy <= 14:
        score += 30
        reasons.append("loss within 14 days of policy inception")

    reporting_delay = (ctx.reported_on - ctx.loss_date).days
    if reporting_delay > 30:
        score += 20
        reasons.append("reported more than 30 days after loss")

    if ctx.loss_type == "theft":
        score += 15
        reasons.append("theft loss type")

    if ctx.prior_claims_on_policy >= 2:
        score += 15
        reasons.append("two or more prior claims on this policy")

    if score >= SIU_THRESHOLD:
        outcome = Outcome.SIU_REVIEW
    elif score >= ADJUSTER_THRESHOLD:
        outcome = Outcome.ADJUSTER_REVIEW
    else:
        outcome = Outcome.FAST_TRACK
    return TriageDecision(score=min(score, 100), outcome=outcome, reasons=reasons)
