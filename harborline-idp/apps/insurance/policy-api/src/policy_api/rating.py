"""Deterministic rating and underwriting engine (pure functions — no I/O, fully unit-tested).

Rates are illustrative for the reference application, not actuarial guidance.
"""

from __future__ import annotations

import datetime as dt
from dataclasses import dataclass, field
from decimal import ROUND_HALF_UP, Decimal

from .models import AutoRisk, HomeRisk, Insured, PremiumBreakdown, Product, QuoteRequest, QuoteStatus

CENT = Decimal("0.01")
POLICY_FEE = Decimal("25.00")

AUTO_BASE = Decimal("900")
AUTO_PROVINCE = {
    "NB": Decimal("0.95"),
    "NS": Decimal("0.95"),
    "PE": Decimal("0.90"),
    "NL": Decimal("1.00"),
    "QC": Decimal("1.05"),
    "ON": Decimal("1.20"),
    "AB": Decimal("1.10"),
}  # BC, MB and SK have public auto insurers: not offered.
DEDUCTIBLE_CREDIT = {500: Decimal("1.00"), 1000: Decimal("0.92"), 2500: Decimal("0.85")}


@dataclass(frozen=True)
class RatingResult:
    status: QuoteStatus
    premium: PremiumBreakdown | None
    reasons: list[str] = field(default_factory=list)


def _q(value: Decimal) -> Decimal:
    return value.quantize(CENT, rounding=ROUND_HALF_UP)


def age_on(dob: dt.date, on: dt.date) -> int:
    return on.year - dob.year - ((on.month, on.day) < (dob.month, dob.day))


def _driver_age_factor(age: int) -> Decimal:
    if age < 25:
        return Decimal("1.60")
    if age < 30:
        return Decimal("1.25")
    if age < 65:
        return Decimal("1.00")
    return Decimal("1.15")


def _km_factor(km: int) -> Decimal:
    if km < 10_000:
        return Decimal("0.90")
    if km < 20_000:
        return Decimal("1.00")
    if km < 30_000:
        return Decimal("1.10")
    return Decimal("1.25")


def _rate_auto(insured: Insured, risk: AutoRisk, deductible: int, on: dt.date) -> RatingResult:
    age = age_on(insured.date_of_birth, on)
    if age < 16:
        return RatingResult(QuoteStatus.DECLINED, None, ["driver below licensing age"])
    if insured.province not in AUTO_PROVINCE:
        return RatingResult(QuoteStatus.DECLINED, None, [f"auto not offered in {insured.province} (public insurer)"])
    reasons: list[str] = []
    factors = {
        "driver_age": _driver_age_factor(age),
        "vehicle_value": min(Decimal("1") + (risk.vehicle_value / Decimal("100000")) * Decimal("0.5"), Decimal("2.5")),
        "annual_km": _km_factor(risk.annual_km),
        "prior_claims": Decimal("1") + Decimal("0.20") * risk.prior_claims,
        "province": AUTO_PROVINCE[insured.province],
        "deductible": DEDUCTIBLE_CREDIT[deductible],
    }
    if risk.prior_claims > 3:
        reasons.append("more than 3 prior claims: underwriter referral")
    if on.year - risk.vehicle_year > 25:
        reasons.append("vehicle older than 25 years: underwriter referral")
    return _finish(AUTO_BASE, factors, reasons)


def _rate_home(insured: Insured, risk: HomeRisk, deductible: int) -> RatingResult:
    reasons: list[str] = []
    base = Decimal("400") + (risk.dwelling_value / Decimal("1000")) * Decimal("1.20")
    if risk.year_built < 1960:
        age_factor = Decimal("1.30")
    elif risk.year_built < 2000:
        age_factor = Decimal("1.10")
    else:
        age_factor = Decimal("1.00")
    factors = {
        "dwelling_age": age_factor,
        "construction": Decimal("1.10") if risk.construction == "wood" else Decimal("1.00"),
        "prior_claims": Decimal("1") + Decimal("0.25") * risk.prior_claims,
        "deductible": DEDUCTIBLE_CREDIT[deductible],
    }
    if risk.dwelling_value > Decimal("5000000"):
        reasons.append("dwelling value above $5M: underwriter referral")
    if risk.prior_claims > 2:
        reasons.append("more than 2 prior property claims: underwriter referral")
    return _finish(base, factors, reasons)


def _finish(base: Decimal, factors: dict[str, Decimal], reasons: list[str]) -> RatingResult:
    premium = base
    for f in factors.values():
        premium *= f
    annual = _q(premium + POLICY_FEE)
    breakdown = PremiumBreakdown(
        base=_q(base),
        factors={k: v.quantize(Decimal("0.001")) for k, v in factors.items()},
        fees=POLICY_FEE,
        annual_premium=annual,
        monthly_premium=_q(annual / 12),
    )
    status = QuoteStatus.REFERRED if reasons else QuoteStatus.QUOTED
    return RatingResult(status, breakdown, reasons)


def rate(request: QuoteRequest, *, on: dt.date | None = None) -> RatingResult:
    """Rate a validated quote request as of `on` (defaults to the effective date)."""
    as_of = on or request.effective_date
    if request.product is Product.AUTO:
        assert isinstance(request.risk, AutoRisk)
        return _rate_auto(request.insured, request.risk, request.deductible, as_of)
    assert isinstance(request.risk, HomeRisk)
    return _rate_home(request.insured, request.risk, request.deductible)
