from __future__ import annotations

import datetime as dt
from contextlib import contextmanager
from typing import Any
from uuid import uuid4

import pytest

from policy_api.config import ConfigError, Settings
from policy_api.messaging import to_cloud_event
from policy_api.outbox import OutboxRelay


class FakeConn:
    @contextmanager
    def transaction(self):  # type: ignore[no-untyped-def]
        yield


class FakePool:
    @contextmanager
    def connection(self):  # type: ignore[no-untyped-def]
        yield FakeConn()


class FakeRepo:
    def __init__(self, rows: list[dict[str, Any]]) -> None:
        self.rows = rows
        self.published: list[int] = []
        self.failed: list[int] = []

    def claim_outbox_batch(self, conn: Any, limit: int) -> list[dict[str, Any]]:
        batch, self.rows = self.rows[:limit], self.rows[limit:]
        return batch

    def mark_published(self, conn: Any, ids: list[int]) -> None:
        self.published += ids

    def mark_failed(self, conn: Any, ids: list[int], error: str) -> None:
        self.failed += ids


class FakePublisher:
    def __init__(self, fail_topics: set[str] | None = None) -> None:
        self.sent: dict[str, list[dict[str, Any]]] = {}
        self.fail_topics = fail_topics or set()

    def publish(self, topic: str, events: list[dict[str, Any]]) -> None:
        if topic in self.fail_topics:
            raise ConnectionError("service bus unavailable")
        self.sent.setdefault(topic, []).extend(events)

    def close(self) -> None:
        pass


def row(i: int, aggregate: str, event: str) -> dict[str, Any]:
    return {
        "id": i,
        "aggregate_type": aggregate,
        "aggregate_id": uuid4(),
        "event_type": event,
        "payload": {"k": "v"},
        "traceparent": "00-" + "a" * 32 + "-" + "b" * 16 + "-01",
        "created_at": dt.datetime(2026, 1, 1, tzinfo=dt.UTC),
    }


def test_relay_routes_events_by_aggregate() -> None:
    repo = FakeRepo([row(1, "claim", "claim.submitted"), row(2, "policy", "policy.bound")])
    pub = FakePublisher()
    assert OutboxRelay(FakePool(), repo, pub).run_once() == 2
    assert [e["type"] for e in pub.sent["claims"]] == ["com.harborline.claim.submitted"]
    assert [e["type"] for e in pub.sent["policies"]] == ["com.harborline.policy.bound"]
    assert sorted(repo.published) == [1, 2]


def test_relay_partial_failure_marks_only_failed_topic() -> None:
    repo = FakeRepo([row(1, "claim", "claim.submitted"), row(2, "policy", "policy.bound")])
    OutboxRelay(FakePool(), repo, FakePublisher(fail_topics={"claims"})).run_once()
    assert repo.published == [2] and repo.failed == [1]


def test_cloud_event_is_deterministic_and_carries_trace() -> None:
    r = row(7, "claim", "claim.submitted")
    a, b = to_cloud_event(r), to_cloud_event(r)
    assert a["id"] == b["id"]  # enables Service Bus duplicate detection
    assert a["specversion"] == "1.0" and a["eventType"] == "claim.submitted"
    assert a["traceparent"].startswith("00-")


def test_settings_reject_unsafe_production_config(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENVIRONMENT", "prod")
    monkeypatch.setenv("AUTH_TENANT_ID", "t")
    monkeypatch.setenv("AUTH_REQUIRED", "false")
    with pytest.raises(ConfigError, match="AUTH_REQUIRED"):
        Settings.from_env()
    monkeypatch.setenv("AUTH_REQUIRED", "true")
    monkeypatch.setenv("DATABASE_PASSWORD", "x")
    with pytest.raises(ConfigError, match="DATABASE_PASSWORD"):
        Settings.from_env()


def test_settings_local_defaults(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENVIRONMENT", "local")
    monkeypatch.setenv("AUTH_REQUIRED", "false")
    s = Settings.from_env()
    assert s.is_local and s.database_sslmode == "disable"
