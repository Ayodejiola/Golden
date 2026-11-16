"""Transactional outbox relay: guarantees at-least-once publication of domain events without 2PC.

Events are inserted in the same DB transaction as the state change; this relay claims batches with
`FOR UPDATE SKIP LOCKED` (safe with many replicas), publishes them, then marks them published.
Consumers are idempotent (claims-worker keeps a processed_messages table).
"""

from __future__ import annotations

import logging
import threading
from collections import defaultdict
from typing import Any

from .messaging import TOPIC_BY_AGGREGATE, Publisher, to_cloud_event

log = logging.getLogger(__name__)


class OutboxRelay:
    def __init__(
        self,
        pool: Any,
        repository: Any,
        publisher: Publisher,
        *,
        poll_seconds: float = 2.0,
        batch_size: int = 50,
        topics: dict[str, str] | None = None,
    ) -> None:
        self.pool = pool
        self.repo = repository
        self.publisher = publisher
        self.poll_seconds = poll_seconds
        self.batch_size = batch_size
        self.topics = topics or TOPIC_BY_AGGREGATE
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self.healthy = True

    def run_once(self) -> int:
        """Publish one batch. Returns the number of events published."""
        with self.pool.connection() as conn, conn.transaction():
            rows = self.repo.claim_outbox_batch(conn, self.batch_size)
            if not rows:
                return 0
            by_topic: dict[str, list[dict[str, Any]]] = defaultdict(list)
            for row in rows:
                by_topic[self.topics[row["aggregate_type"]]].append(row)
            published: list[int] = []
            for topic, topic_rows in by_topic.items():
                ids = [r["id"] for r in topic_rows]
                try:
                    self.publisher.publish(topic, [to_cloud_event(r) for r in topic_rows])
                    published.extend(ids)
                except Exception as exc:  # noqa: BLE001 - recorded and retried
                    log.warning(
                        "outbox publish failed",
                        extra={"topic": topic, "count": len(ids), "error.type": type(exc).__name__},
                    )
                    self.repo.mark_failed(conn, ids, type(exc).__name__)
            if published:
                self.repo.mark_published(conn, published)
            return len(published)

    def _loop(self) -> None:
        while not self._stop.is_set():
            try:
                n = self.run_once()
                self.healthy = True
                if n == self.batch_size:
                    continue  # drain backlog without waiting
            except Exception:
                self.healthy = False
                log.exception("outbox relay iteration failed")
            self._stop.wait(self.poll_seconds)

    def start(self) -> None:
        self._thread = threading.Thread(target=self._loop, name="outbox-relay", daemon=True)
        self._thread.start()

    def stop(self, timeout: float = 10.0) -> None:
        self._stop.set()
        if self._thread:
            self._thread.join(timeout)
        self.publisher.close()
