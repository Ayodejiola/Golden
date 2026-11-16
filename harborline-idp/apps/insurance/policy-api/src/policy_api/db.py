"""PostgreSQL connection pool authenticated with Microsoft Entra tokens (workload identity, ADR-0007).

Each new physical connection fetches a fresh access token as its password; tokens are only checked at
connect time, and pool max_lifetime keeps connections well inside token validity.
"""

from __future__ import annotations

import logging
from collections.abc import Callable
from typing import Any

from .config import Settings

log = logging.getLogger(__name__)
ENTRA_PG_SCOPE = "https://ossrdbms-aad.database.windows.net/.default"


def token_provider_factory(settings: Settings) -> Callable[[], str]:
    if settings.database_password:  # local development only (validated in Settings)
        password = settings.database_password
        return lambda: password
    from azure.identity import DefaultAzureCredential

    credential = DefaultAzureCredential(exclude_interactive_browser_credential=True)
    return lambda: credential.get_token(ENTRA_PG_SCOPE).token


def create_pool(settings: Settings, *, min_size: int = 2, max_size: int = 10) -> Any:
    import psycopg
    from psycopg.rows import dict_row
    from psycopg_pool import ConnectionPool

    get_password = token_provider_factory(settings)

    class EntraConnection(psycopg.Connection):  # type: ignore[type-arg]
        @classmethod
        def connect(cls, conninfo: str = "", **kwargs: Any) -> Any:  # type: ignore[override]
            kwargs["password"] = get_password()
            return super().connect(conninfo, **kwargs)

    conninfo = psycopg.conninfo.make_conninfo(
        host=settings.database_host,
        dbname=settings.database_name,
        user=settings.database_user,
        sslmode=settings.database_sslmode,
        application_name="policy-api",
        connect_timeout=5,
    )
    pool = ConnectionPool(
        conninfo,
        connection_class=EntraConnection,
        kwargs={"row_factory": dict_row, "options": "-c statement_timeout=5000"},
        min_size=min_size,
        max_size=max_size,
        max_lifetime=45 * 60,
        max_idle=5 * 60,
        open=False,
        name="policy-api",
    )
    pool.open(wait=False)
    return pool
