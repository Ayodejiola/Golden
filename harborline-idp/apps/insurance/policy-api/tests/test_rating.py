from __future__ import annotations

import datetime as dt
from decimal import Decimal

from policy_api.models import QuoteRequest, QuoteStatus
from policy_api.rating import POLICY_FEE, age_on, rate


def test_standard_auto_quote_is_priced(auto_request: dict) -> None:
    result = rate(QuoteRequest.model_validate(auto_request))
    assert result.status is QuoteStatus.QUOTED
    assert result.premium is not None
    # 900 * age 1.00 * value 1.15 * km 1.00 * claims 1.00 * NB 0.95 * deductible 0.92 + 25 fee
    expected = (Decimal("900") * Decimal("1.15") * Decimal("0.95") * Decimal("0.92") + POLICY_FEE).quantize(
        Decimal("0.01")
    )
    assert result.premium.annual_premium == expected
    assert result.premium.monthly_premium == (expected / 12).quantize(Decimal("0.01"))


def test_young_driver_costs_more(auto_request: dict, today: dt.date) -> None:
    base = rate(QuoteRequest.model_validate(auto_request)).premium
    auto_request["insured"]["date_of_birth"] = str(today.replace(year=today.year - 20))
    young = rate(QuoteRequest.model_validate(auto_request)).premium
    assert base is not None and young is not None
    assert young.annual_premium > base.annual_premium
    assert young.factors["driver_age"] == Decimal("1.600")


def test_auto_declined_in_public_insurance_province(auto_request: dict) -> None:
    auto_request["insured"]["province"] = "BC"
    result = rate(QuoteRequest.model_validate(auto_request))
    assert result.status is QuoteStatus.DECLINED
    assert result.premium is None
    assert "public insurer" in result.reasons[0]


def test_underage_driver_declined(auto_request: dict, today: dt.date) -> None:
    auto_request["insured"]["date_of_birth"] = str(today.replace(year=today.year - 15))
    assert rate(QuoteRequest.model_validate(auto_request)).status is QuoteStatus.DECLINED


def test_many_prior_claims_referred(auto_request: dict) -> None:
    auto_request["risk"]["prior_claims"] = 4
    result = rate(QuoteRequest.model_validate(auto_request))
    assert result.status is QuoteStatus.REFERRED
    assert result.premium is not None  # indicative premium still shown to the underwriter


def test_home_quote_factors(home_request: dict) -> None:
    result = rate(QuoteRequest.model_validate(home_request))
    assert result.status is QuoteStatus.QUOTED
    assert result.premium is not None
    assert result.premium.factors == {
        "dwelling_age": Decimal("1.100"),
        "construction": Decimal("1.100"),
        "prior_claims": Decimal("1.250"),
        "deductible": Decimal("1.000"),
    }
    assert result.premium.base == Decimal("940.00")  # 400 + 450 * 1.20


def test_high_value_home_referred(home_request: dict) -> None:
    home_request["risk"]["dwelling_value"] = "6000000"
    assert rate(QuoteRequest.model_validate(home_request)).status is QuoteStatus.REFERRED


def test_age_on_birthday_boundary() -> None:
    assert age_on(dt.date(2000, 6, 15), dt.date(2025, 6, 14)) == 24
    assert age_on(dt.date(2000, 6, 15), dt.date(2025, 6, 15)) == 25


def test_rating_is_deterministic(auto_request: dict) -> None:
    req = QuoteRequest.model_validate(auto_request)
    assert rate(req) == rate(req)
