from __future__ import annotations

import datetime as dt

import pytest
from pydantic import ValidationError

from policy_api.models import ClaimRequest, QuoteRequest


def test_valid_quote_request(auto_request: dict) -> None:
    assert QuoteRequest.model_validate(auto_request).product.value == "auto"


def test_unknown_fields_rejected(auto_request: dict) -> None:
    auto_request["is_admin"] = True  # mass-assignment attempt (ASVS V2/V4)
    with pytest.raises(ValidationError):
        QuoteRequest.model_validate(auto_request)


def test_product_must_match_risk(auto_request: dict, home_request: dict) -> None:
    auto_request["risk"] = home_request["risk"]
    with pytest.raises(ValidationError, match=r"risk\.kind must match product"):
        QuoteRequest.model_validate(auto_request)


def test_effective_date_window(auto_request: dict, today: dt.date) -> None:
    auto_request["effective_date"] = str(today + dt.timedelta(days=120))
    with pytest.raises(ValidationError):
        QuoteRequest.model_validate(auto_request)


@pytest.mark.parametrize("name", ["<script>", "Robert'); DROP TABLE quotes;--", "a" * 81])
def test_names_are_constrained(auto_request: dict, name: str) -> None:
    auto_request["insured"]["first_name"] = name
    with pytest.raises(ValidationError):
        QuoteRequest.model_validate(auto_request)


def test_email_format(auto_request: dict) -> None:
    auto_request["insured"]["email"] = "not-an-email"
    with pytest.raises(ValidationError):
        QuoteRequest.model_validate(auto_request)


def test_claim_cannot_be_in_future(today: dt.date) -> None:
    with pytest.raises(ValidationError):
        ClaimRequest.model_validate(
            {
                "policy_number": "HBL-AU-2026-100001",
                "loss_date": str(today + dt.timedelta(days=1)),
                "loss_type": "collision",
                "description": "Rear-ended at a stop light.",
                "estimated_amount": "3500.00",
            }
        )


def test_claim_policy_number_format(today: dt.date) -> None:
    with pytest.raises(ValidationError):
        ClaimRequest.model_validate(
            {
                "policy_number": "../../etc/passwd",
                "loss_date": str(today),
                "loss_type": "theft",
                "description": "Bicycle stolen from garage.",
                "estimated_amount": "900",
            }
        )
