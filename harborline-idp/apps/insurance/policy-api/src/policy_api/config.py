"""Twelve-factor configuration from environment variables (set by the golden-service chart ConfigMap)."""

from __future__ import annotations

import os
from dataclasses import dataclass


class ConfigError(RuntimeError):
    """Raised when configuration is missing or unsafe."""


def _env(name: str, default: str | None = None) -> str:
    value = os.environ.get(name, default)
    if value is None or value == "":
        raise ConfigError(f"missing required environment variable {name}")
    return value


def _bool(name: str, default: str) -> bool:
    return os.environ.get(name, default).strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True, slots=True)
class Settings:
    environment: str
    port: int
    log_level: str
    database_host: str
    database_name: str
    database_user: str
    database_password: str | None  # local development only; Azure uses Entra tokens
    database_sslmode: str
    servicebus_fqdn: str | None
    servicebus_connection_string: str | None  # local emulator only
    claims_topic: str
    policies_topic: str
    auth_required: bool
    auth_tenant_id: str
    auth_audience: str
    outbox_poll_seconds: float

    @property
    def is_local(self) -> bool:
        return self.environment == "local"

    @classmethod
    def from_env(cls) -> Settings:
        environment = os.environ.get("APP_ENVIRONMENT", "local")
        settings = cls(
            environment=environment,
            port=int(os.environ.get("PORT", "8080")),
            log_level=os.environ.get("LOG_LEVEL", "INFO").upper(),
            database_host=_env("DATABASE_HOST", "localhost"),
            database_name=_env("DATABASE_NAME", "insurance"),
            database_user=_env("DATABASE_USER", "policy_api"),
            database_password=os.environ.get("DATABASE_PASSWORD") or None,
            database_sslmode=os.environ.get("DATABASE_SSLMODE", "disable" if environment == "local" else "require"),
            servicebus_fqdn=os.environ.get("SERVICEBUS_FQDN") or None,
            servicebus_connection_string=os.environ.get("SERVICEBUS_CONNECTION_STRING") or None,
            claims_topic=os.environ.get("SERVICEBUS_CLAIMS_TOPIC", "claims"),
            policies_topic=os.environ.get("SERVICEBUS_POLICIES_TOPIC", "policies"),
            auth_required=_bool("AUTH_REQUIRED", "true"),
            auth_tenant_id=os.environ.get("AUTH_TENANT_ID", ""),
            auth_audience=os.environ.get("AUTH_AUDIENCE", "api://harborline-policy-api"),
            outbox_poll_seconds=float(os.environ.get("OUTBOX_POLL_SECONDS", "2")),
        )
        settings.validate()
        return settings

    def validate(self) -> None:
        """Fail fast on unsafe combinations (ASVS V13 configuration)."""
        if not self.is_local:
            if not self.auth_required:
                raise ConfigError("AUTH_REQUIRED=false is only allowed when APP_ENVIRONMENT=local")
            if self.database_password:
                raise ConfigError("DATABASE_PASSWORD must not be set outside local; use workload identity")
            if self.servicebus_connection_string:
                raise ConfigError("SERVICEBUS_CONNECTION_STRING must not be set outside local; use workload identity")
            if self.database_sslmode not in {"require", "verify-ca", "verify-full"}:
                raise ConfigError("TLS to PostgreSQL is mandatory outside local")
            if not self.auth_tenant_id:
                raise ConfigError("AUTH_TENANT_ID is required")
