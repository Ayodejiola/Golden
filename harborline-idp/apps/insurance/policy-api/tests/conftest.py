from __future__ import annotations

import datetime as dt
import os

import pytest

os.environ.setdefault("OTEL_SDK_DISABLED", "true")


@pytest.fixture
def today() -> dt.date:
    return dt.date.today()


@pytest.fixture
def auto_request(today: dt.date) -> dict:
    """Synthetic applicant — not a real person."""
    return {
        "product": "auto",
        "insured": {
            "first_name": "Avery",
            "last_name": "Testcase",
            "email": "avery.testcase@example.com",
            "date_of_birth": str(today.replace(year=today.year - 40) - dt.timedelta(days=1)),
            "province": "NB",
        },
        "risk": {
            "kind": "auto",
            "vehicle_year": today.year - 3,
            "vehicle_value": "30000",
            "annual_km": 15000,
            "prior_claims": 0,
        },
        "deductible": 1000,
        "effective_date": str(today + dt.timedelta(days=7)),
    }


@pytest.fixture
def home_request(today: dt.date) -> dict:
    return {
        "product": "home",
        "insured": {
            "first_name": "Jordan",
            "last_name": "Sample",
            "email": "jordan.sample@example.com",
            "date_of_birth": "1980-05-17",
            "province": "NS",
        },
        "risk": {
            "kind": "home",
            "dwelling_value": "450000",
            "year_built": 1995,
            "construction": "wood",
            "prior_claims": 1,
        },
        "deductible": 500,
        "effective_date": str(today + dt.timedelta(days=1)),
    }
