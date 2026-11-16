"""Schema migrations + least-privilege role provisioning. Runs as the Argo CD PreSync hook job
(golden-service `migrations`) under the db-migrator workload identity, an Entra admin of this server only.

Steps (idempotent, serialised with an advisory lock so concurrent jobs cannot interleave):
  1. apply migrations/NNNN_*.sql not yet recorded in schema_migrations, each in its own transaction
  2. ensure Entra principals exist for the app identities (pgaadauth_create_principal)
  3. grant exactly the privileges each app needs (no DDL, no superuser, no ownership)
"""

from __future__ import annotations

import hashlib
import logging
import os
import sys
from pathlib import Path

from .config import Settings
from .logging_config import configure_logging

log = logging.getLogger("policy_api.migrate")
LOCK_ID = 7_242_026  # arbitrary, constant advisory lock key
MIGRATIONS_DIR = Path(os.environ.get("MIGRATIONS_DIR", Path(__file__).resolve().parents[2] / "migrations"))

# Least-privilege grants per application role (role name = managed identity name, suffixed by env).
GRANTS = {
    "policy-api": [
        "GRANT SELECT, INSERT, UPDATE ON quotes, policies, claims TO {role}",
        "GRANT SELECT, INSERT, UPDATE ON outbox TO {role}",
        "GRANT USAGE ON SEQUENCE policy_number_seq, claim_number_seq, outbox_id_seq TO {role}",
    ],
    "claims-worker": [
        "GRANT SELECT ON policies TO {role}",
        "GRANT SELECT, UPDATE (status, triage_score, triage_outcome, triage_reasons, updated_at) ON claims TO {role}",
        "GRANT SELECT, INSERT ON processed_messages TO {role}",
    ],
}


def pending_migrations(applied: set[str]) -> list[Path]:
    files = sorted(MIGRATIONS_DIR.glob("[0-9][0-9][0-9][0-9]_*.sql"))
    return [f for f in files if f.name not in applied]


def checksum(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    settings = Settings.from_env()
    configure_logging("policy-api-migrate", settings.environment, settings.log_level)
    import psycopg
    from psycopg import sql

    from .db import token_provider_factory

    user = os.environ.get("DATABASE_MIGRATION_USER", settings.database_user)
    password = token_provider_factory(settings)()
    env = settings.environment
    with psycopg.connect(
        host=settings.database_host,
        dbname=settings.database_name,
        user=user,
        password=password,
        sslmode=settings.database_sslmode,
        autocommit=True,
        application_name="policy-api-migrate",
    ) as conn:
        conn.execute("SELECT pg_advisory_lock(%s)", (LOCK_ID,))
        try:
            conn.execute("""CREATE TABLE IF NOT EXISTS schema_migrations (
                              version text PRIMARY KEY, checksum text NOT NULL,
                              applied_at timestamptz NOT NULL DEFAULT now())""")
            rows = conn.execute("SELECT version, checksum FROM schema_migrations").fetchall()
            applied = {r[0]: r[1] for r in rows}
            for name, digest in applied.items():
                f = MIGRATIONS_DIR / name
                if f.exists() and checksum(f) != digest:
                    log.error("applied migration was modified", extra={"migration": name})
                    return 2
            for f in pending_migrations(set(applied)):
                log.info("applying migration", extra={"migration": f.name})
                with conn.transaction():
                    conn.execute(f.read_text())  # trusted, reviewed files from the image
                    conn.execute(
                        "INSERT INTO schema_migrations (version, checksum) VALUES (%s, %s)", (f.name, checksum(f))
                    )

            if not settings.is_local:
                for app, statements in GRANTS.items():
                    role = f"id-ins-{app}-{env}"
                    exists = conn.execute("SELECT 1 FROM pg_roles WHERE rolname = %s", (role,)).fetchone()
                    if not exists:
                        conn.execute("SELECT * FROM pgaadauth_create_principal(%s, false, false)", (role,))
                        log.info("created entra principal", extra={"role": role})
                    with conn.transaction():
                        for stmt in statements:
                            conn.execute(sql.SQL(stmt).format(role=sql.Identifier(role)))
        finally:
            conn.execute("SELECT pg_advisory_unlock(%s)", (LOCK_ID,))
    log.info("migrations complete")
    return 0


if __name__ == "__main__":
    sys.exit(main())
