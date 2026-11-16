"""Integration tests against a real PostgreSQL (CI service container or `make app-up`).

Run: RUN_INTEGRATION=1 DATABASE_PASSWORD=... python -m pytest -m integration tests/integration
"""

from __future__ import annotations

import datetime as dt
import os
from decimal import Decimal

import pytest

pytestmark = [
    pytest.mark.integration,
    pytest.mark.skipif(os.environ.get("RUN_INTEGRATION") != "1", reason="set RUN_INTEGRATION=1"),
]


@pytest.fixture(scope="module")
def repo():  # type: ignore[no-untyped-def]
    from policy_api.config import Settings
    from policy_api.db import create_pool
    from policy_api.repository import Repository

    pool = create_pool(Settings.from_env(), min_size=1, max_size=2)
    pool.wait(timeout=10)
    yield Repository(pool)
    pool.close()


def test_quote_bind_claim_and_outbox(repo, auto_request: dict) -> None:  # type: ignore[no-untyped-def]
    from policy_api.models import ClaimRequest, QuoteRequest
    from policy_api.outbox import OutboxRelay
    from policy_api.rating import rate

    owner = "it-user-1"
    today = dt.date.today()
    auto_request["effective_date"] = str(today)
    req = QuoteRequest.model_validate(auto_request)
    quote = repo.create_quote(req, rate(req), owner)
    policy = repo.bind_policy(quote["id"], owner, None)
    assert policy is not None and policy["policy_number"].startswith("HBL-AU-")
    assert Decimal(policy["annual_premium"]) > 0

    # A quote binds once, and only for its owner (no IDOR).
    assert repo.bind_policy(quote["id"], owner, None) is None
    assert repo.bind_policy(quote["id"], "someone-else", None) is None
    assert repo.get_policy(policy["policy_number"], "someone-else") is None

    claim = repo.submit_claim(
        ClaimRequest.model_validate(
            {
                "policy_number": policy["policy_number"],
                "loss_date": str(today),
                "loss_type": "collision",
                "description": "Integration test synthetic loss.",
                "estimated_amount": "2500.00",
            }
        ),
        owner,
        None,
    )
    assert claim is not None and claim["claim_number"].startswith("CLM-")

    published: list[dict] = []

    class Capture:
        def publish(self, topic: str, events: list[dict]) -> None:
            published.extend(events)

        def close(self) -> None:
            pass

    assert OutboxRelay(repo.pool, repo, Capture()).run_once() >= 2
    types = {e["type"] for e in published}
    assert {"com.harborline.policy.bound", "com.harborline.claim.submitted"} <= types
    assert repo.pending_outbox() == 0
