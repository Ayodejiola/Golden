"""Data access. All SQL is parameterised (ASVS V1/V5 injection prevention); no string-built queries."""

from __future__ import annotations

import datetime as dt
import json
from decimal import Decimal
from typing import Any
from uuid import UUID

from .models import ClaimRequest, Product, QuoteRequest
from .rating import RatingResult

QUOTE_TTL = dt.timedelta(days=30)


def _json(obj: Any) -> str:
    return json.dumps(obj, default=str)


class Repository:
    def __init__(self, pool: Any) -> None:
        self.pool = pool

    def ping(self) -> bool:
        with self.pool.connection(timeout=2) as conn:
            return conn.execute("SELECT 1 AS ok").fetchone()["ok"] == 1

    # ---------- quotes ----------
    def create_quote(self, req: QuoteRequest, result: RatingResult, created_by: str) -> dict[str, Any]:
        premium = result.premium.annual_premium if result.premium else None
        with self.pool.connection() as conn:
            return conn.execute(
                """
                INSERT INTO quotes (product, status, insured, risk, deductible, effective_date,
                                    annual_premium, breakdown, reasons, expires_at, created_by)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, now() + %s, %s)
                RETURNING id, product, status, breakdown, reasons, expires_at
                """,
                (
                    req.product.value,
                    result.status.value,
                    _json(req.insured.model_dump()),
                    _json(req.risk.model_dump()),
                    req.deductible,
                    req.effective_date,
                    premium,
                    _json(result.premium.model_dump()) if result.premium else None,
                    _json(result.reasons),
                    QUOTE_TTL,
                    created_by,
                ),
            ).fetchone()

    def get_quote_for_update(self, conn: Any, quote_id: UUID, owner: str) -> dict[str, Any] | None:
        return conn.execute(
            "SELECT * FROM quotes WHERE id = %s AND created_by = %s FOR UPDATE", (quote_id, owner)
        ).fetchone()

    # ---------- policies ----------
    def bind_policy(self, quote_id: UUID, owner: str, traceparent: str | None) -> dict[str, Any] | None:
        """Bind a quote atomically and enqueue `policy.bound` in the same transaction (transactional outbox)."""
        with self.pool.connection() as conn, conn.transaction():
            quote = self.get_quote_for_update(conn, quote_id, owner)
            if quote is None or quote["status"] != "quoted" or quote["expires_at"] < dt.datetime.now(dt.UTC):
                return None
            prefix = "AU" if quote["product"] == Product.AUTO.value else "HO"
            policy = conn.execute(
                """
                INSERT INTO policies (policy_number, quote_id, product, status, effective_date, expiry_date,
                                      annual_premium, insured, created_by)
                VALUES ('HBL-' || %s || '-' || to_char(%s::date, 'YYYY') || '-' ||
                        lpad(nextval('policy_number_seq')::text, 6, '0'),
                        %s, %s, 'active', %s, (%s::date + interval '1 year')::date, %s, %s, %s)
                RETURNING id, policy_number, product, status, effective_date, expiry_date, annual_premium
                """,
                (
                    prefix,
                    quote["effective_date"],
                    quote_id,
                    quote["product"],
                    quote["effective_date"],
                    quote["effective_date"],
                    quote["annual_premium"],
                    _json(quote["insured"]),
                    owner,
                ),
            ).fetchone()
            conn.execute("UPDATE quotes SET status = 'bound' WHERE id = %s", (quote_id,))
            self._enqueue(
                conn,
                "policy",
                policy["id"],
                "policy.bound",
                {
                    "policy_id": str(policy["id"]),
                    "policy_number": policy["policy_number"],
                    "product": policy["product"],
                    "annual_premium": str(policy["annual_premium"]),
                    "effective_date": str(policy["effective_date"]),
                },
                traceparent,
            )
            return policy

    def list_policies(self, owner: str, limit: int = 50) -> list[dict[str, Any]]:
        with self.pool.connection() as conn:
            return conn.execute(
                """SELECT id, policy_number, product, status, effective_date, expiry_date, annual_premium
                   FROM policies WHERE created_by = %s ORDER BY created_at DESC LIMIT %s""",
                (owner, limit),
            ).fetchall()

    def get_policy(self, policy_number: str, owner: str) -> dict[str, Any] | None:
        with self.pool.connection() as conn:
            return conn.execute(
                """SELECT id, policy_number, product, status, effective_date, expiry_date, annual_premium
                   FROM policies WHERE policy_number = %s AND created_by = %s""",
                (policy_number, owner),
            ).fetchone()

    # ---------- claims ----------
    def submit_claim(self, req: ClaimRequest, owner: str, traceparent: str | None) -> dict[str, Any] | None:
        with self.pool.connection() as conn, conn.transaction():
            policy = conn.execute(
                "SELECT id, effective_date, expiry_date, status FROM policies "
                "WHERE policy_number = %s AND created_by = %s",
                (req.policy_number, owner),
            ).fetchone()
            if policy is None or policy["status"] != "active":
                return None
            if not (policy["effective_date"] <= req.loss_date <= policy["expiry_date"]):
                raise ValueError("loss_date is outside the policy period")
            claim = conn.execute(
                """
                INSERT INTO claims (claim_number, policy_id, loss_date, loss_type, description,
                                    estimated_amount, status, created_by)
                VALUES ('CLM-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('claim_number_seq')::text, 7, '0'),
                        %s, %s, %s, %s, %s, 'submitted', %s)
                RETURNING id, claim_number, status, loss_type, loss_date, created_at
                """,
                (policy["id"], req.loss_date, req.loss_type.value, req.description, req.estimated_amount, owner),
            ).fetchone()
            # Event carries no PII (no names, no description): consumers fetch details with their own authZ.
            self._enqueue(
                conn,
                "claim",
                claim["id"],
                "claim.submitted",
                {
                    "claim_id": str(claim["id"]),
                    "claim_number": claim["claim_number"],
                    "policy_id": str(policy["id"]),
                    "loss_type": req.loss_type.value,
                    "loss_date": str(req.loss_date),
                    "estimated_amount": str(req.estimated_amount),
                },
                traceparent,
            )
            return {**claim, "policy_number": req.policy_number, "triage_outcome": None}

    def get_claim(self, claim_number: str, owner: str) -> dict[str, Any] | None:
        with self.pool.connection() as conn:
            return conn.execute(
                """SELECT c.id, c.claim_number, p.policy_number, c.status, c.loss_type, c.loss_date,
                          c.triage_outcome, c.created_at
                   FROM claims c JOIN policies p ON p.id = c.policy_id
                   WHERE c.claim_number = %s AND (c.created_by = %s)""",
                (claim_number, owner),
            ).fetchone()

    # ---------- outbox ----------
    @staticmethod
    def _enqueue(
        conn: Any, aggregate: str, aggregate_id: UUID, event_type: str, data: dict[str, Any], traceparent: str | None
    ) -> None:
        conn.execute(
            """INSERT INTO outbox (aggregate_type, aggregate_id, event_type, payload, traceparent)
               VALUES (%s, %s, %s, %s, %s)""",
            (aggregate, aggregate_id, event_type, _json(data), traceparent),
        )

    def claim_outbox_batch(self, conn: Any, limit: int = 50) -> list[dict[str, Any]]:
        return conn.execute(
            """SELECT id, aggregate_type, aggregate_id, event_type, payload, traceparent, created_at
               FROM outbox WHERE published_at IS NULL AND attempts < 20
               ORDER BY id LIMIT %s FOR UPDATE SKIP LOCKED""",
            (limit,),
        ).fetchall()

    @staticmethod
    def mark_published(conn: Any, ids: list[int]) -> None:
        conn.execute("UPDATE outbox SET published_at = now() WHERE id = ANY(%s)", (ids,))

    @staticmethod
    def mark_failed(conn: Any, ids: list[int], error: str) -> None:
        conn.execute(
            "UPDATE outbox SET attempts = attempts + 1, last_error = left(%s, 500) WHERE id = ANY(%s)", (error, ids)
        )

    def pending_outbox(self) -> int:
        with self.pool.connection() as conn:
            row = conn.execute("SELECT count(*) AS n FROM outbox WHERE published_at IS NULL").fetchone()
            return int(row["n"])


def to_decimal(value: Any) -> Decimal:
    return value if isinstance(value, Decimal) else Decimal(str(value))
