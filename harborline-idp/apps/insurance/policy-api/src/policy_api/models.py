"""API contract (pydantic v2). Strict input validation is the first line of defence (ASVS V2, V4)."""

from __future__ import annotations

import datetime as dt
from decimal import Decimal
from enum import StrEnum
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

Money = Annotated[Decimal, Field(ge=0, max_digits=12, decimal_places=2)]
Province = Literal["AB", "BC", "MB", "NB", "NL", "NS", "ON", "PE", "QC", "SK"]
Name = Annotated[str, Field(min_length=1, max_length=80, pattern=r"^[\w .'\-]+$")]
Email = Annotated[str, Field(max_length=254, pattern=r"^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$")]


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True, frozen=True)


class Product(StrEnum):
    AUTO = "auto"
    HOME = "home"


class QuoteStatus(StrEnum):
    QUOTED = "quoted"
    REFERRED = "referred"
    DECLINED = "declined"
    BOUND = "bound"


class Insured(Strict):
    first_name: Name
    last_name: Name
    email: Email
    date_of_birth: dt.date
    province: Province

    @field_validator("date_of_birth")
    @classmethod
    def plausible_dob(cls, v: dt.date) -> dt.date:
        today = dt.date.today()
        if v >= today or (today.year - v.year) > 120:
            raise ValueError("date_of_birth is not plausible")
        return v


class AutoRisk(Strict):
    kind: Literal["auto"] = "auto"
    vehicle_year: int = Field(ge=1980, le=dt.date.today().year + 1)
    vehicle_value: Money = Field(le=Decimal("500000"))
    annual_km: int = Field(ge=0, le=200_000)
    prior_claims: int = Field(ge=0, le=20)


class HomeRisk(Strict):
    kind: Literal["home"] = "home"
    dwelling_value: Money = Field(ge=Decimal("50000"), le=Decimal("20000000"))
    year_built: int = Field(ge=1800, le=dt.date.today().year)
    construction: Literal["wood", "masonry"]
    prior_claims: int = Field(ge=0, le=20)


class QuoteRequest(Strict):
    product: Product
    insured: Insured
    risk: Annotated[AutoRisk | HomeRisk, Field(discriminator="kind")]
    deductible: Literal[500, 1000, 2500] = 1000
    effective_date: dt.date

    @model_validator(mode="after")
    def product_matches_risk(self) -> QuoteRequest:
        if self.product.value != self.risk.kind:
            raise ValueError("risk.kind must match product")
        today = dt.date.today()
        if not (today <= self.effective_date <= today + dt.timedelta(days=90)):
            raise ValueError("effective_date must be within the next 90 days")
        return self


class PremiumBreakdown(Strict):
    base: Money
    factors: dict[str, Decimal]
    fees: Money
    annual_premium: Money
    monthly_premium: Money


class Quote(Strict):
    id: UUID
    product: Product
    status: QuoteStatus
    premium: PremiumBreakdown | None
    reasons: list[str] = []
    expires_at: dt.datetime
    currency: Literal["CAD"] = "CAD"


class BindRequest(Strict):
    quote_id: UUID
    accept_terms: Literal[True]


class Policy(Strict):
    id: UUID
    policy_number: str
    product: Product
    status: Literal["active", "cancelled"]
    effective_date: dt.date
    expiry_date: dt.date
    annual_premium: Money


class LossType(StrEnum):
    COLLISION = "collision"
    THEFT = "theft"
    FIRE = "fire"
    WATER = "water"
    WEATHER = "weather"
    LIABILITY = "liability"


class ClaimRequest(Strict):
    policy_number: Annotated[str, Field(pattern=r"^HBL-(AU|HO)-\d{4}-\d{6}$")]
    loss_date: dt.date
    loss_type: LossType
    description: Annotated[str, Field(min_length=10, max_length=2000)]
    estimated_amount: Money = Field(le=Decimal("5000000"))

    @field_validator("loss_date")
    @classmethod
    def not_in_future(cls, v: dt.date) -> dt.date:
        if v > dt.date.today():
            raise ValueError("loss_date cannot be in the future")
        return v


class Claim(Strict):
    id: UUID
    claim_number: str
    policy_number: str
    status: Literal["submitted", "triaged", "rejected"]
    loss_type: LossType
    loss_date: dt.date
    triage_outcome: str | None = None
    created_at: dt.datetime


class Problem(BaseModel):
    """RFC 9457 problem details — the only error shape the API returns."""

    type: str = "about:blank"
    title: str
    status: int
    detail: str | None = None
    correlation_id: str | None = None
