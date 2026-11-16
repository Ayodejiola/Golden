"""PostgreSQL implementation of the handler Store (Entra token auth via workload identity)."""

from __future__ import annotations

import json
import os
from collections.abc import Iterator
from contextlib import contextmanager
from typing import Any

from .handler import TransientError
from .triage import TriageDecision

ENTRA_PG_SCOPE = "https://ossrdbms-aad.database.windows.net/.default"


class PostgresStore:
    def __init__(self) -> None:
        import psycopg
        from psycopg.rows import dict_row
        from psycopg_pool import ConnectionPool

        local_password = os.environ.get("DATABASE_PASSWORD")
        if local_password and os.environ.get("APP_ENVIRONMENT", "local") != "local":
            raise RuntimeError("DATABASE_PASSWORD is only allowed locally; use workload identity")
        if local_password:

            def get_password() -> str:
                return local_password
        else:
            from azure.identity import DefaultAzureCredential

            credential = DefaultAzureCredential(exclude_interactive_browser_credential=True)

            def get_password() -> str:
                return credential.get_token(ENTRA_PG_SCOPE).token

        class EntraConnection(psycopg.Connection):  # type: ignore[type-arg]
            @classmethod
            def connect(cls, conninfo: str = "", **kwargs: Any) -> Any:  # type: ignore[override]
                kwargs["password"] = get_password()
                return super().connect(conninfo, **kwargs)

        env = os.environ.get("APP_ENVIRONMENT", "local")
        conninfo = psycopg.conninfo.make_conninfo(
            host=os.environ.get("DATABASE_HOST", "localhost"),
            dbname=os.environ.get("DATABASE_NAME", "insurance"),
            user=os.environ.get("DATABASE_USER", "claims_worker"),
            sslmode=os.environ.get("DATABASE_SSLMODE", "disable" if env == "local" else "require"),
            application_name="claims-worker",
            connect_timeout=5,
        )
        self._operational_error = psycopg.OperationalError
        self.pool = ConnectionPool(
            conninfo,
            connection_class=EntraConnection,
            kwargs={"row_factory": dict_row},
            min_size=1,
            max_size=int(os.environ.get("MAX_CONCURRENCY", "4")) + 1,
            max_lifetime=45 * 60,
            open=True,
            name="claims-worker",
        )

    @contextmanager
    def transaction(self) -> Iterator[Any]:
        try:
            with self.pool.connection() as conn, conn.transaction():
                yield conn
        except self._operational_error as exc:
            raise TransientError(str(exc)) from exc

    @staticmethod
    def mark_processed(tx: Any, message_id: str, consumer: str) -> bool:
        row = tx.execute(
            """INSERT INTO processed_messages (message_id, consumer) VALUES (%s, %s)
               ON CONFLICT (message_id) DO NOTHING RETURNING message_id""",
            (message_id, consumer),
        ).fetchone()
        return row is not None

    @staticmethod
    def load_claim(tx: Any, claim_id: str) -> dict[str, Any] | None:
        return tx.execute(
            """SELECT c.id, c.created_at, p.effective_date AS policy_effective_date,
                      (SELECT count(*) FROM claims c2 WHERE c2.policy_id = c.policy_id AND c2.id <> c.id)
                        AS prior_claims_on_policy
               FROM claims c JOIN policies p ON p.id = c.policy_id
               WHERE c.id = %s FOR UPDATE OF c""",
            (claim_id,),
        ).fetchone()

    @staticmethod
    def save_triage(tx: Any, claim_id: str, decision: TriageDecision) -> None:
        tx.execute(
            """UPDATE claims SET status = 'triaged', triage_score = %s, triage_outcome = %s,
                                 triage_reasons = %s, updated_at = now()
               WHERE id = %s""",
            (decision.score, decision.outcome.value, json.dumps(decision.reasons), claim_id),
        )

    def ping(self) -> bool:
        with self.pool.connection(timeout=2) as conn:
            return conn.execute("SELECT 1 AS ok").fetchone()["ok"] == 1

    def close(self) -> None:
        self.pool.close()
