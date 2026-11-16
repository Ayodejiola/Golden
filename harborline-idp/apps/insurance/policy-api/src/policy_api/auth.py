"""Microsoft Entra ID access-token validation and authorisation (framework-agnostic, unit-tested).

ASVS V9/V10: signature (RS256 via tenant JWKS), issuer, audience, expiry/not-before with small leeway,
and explicit scope/app-role checks on every operation. Tokens are never logged.
"""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass, field
from typing import Any, Protocol

import jwt

ALLOWED_ALGORITHMS = ["RS256"]


class AuthError(Exception):
    """Authentication failed (HTTP 401)."""


class ForbiddenError(Exception):
    """Authenticated but not authorised (HTTP 403)."""


class SigningKeyResolver(Protocol):
    def get_signing_key_from_jwt(self, token: str) -> Any: ...


@dataclass(frozen=True)
class Principal:
    subject: str  # Entra object id (oid) — stable, non-PII identifier
    tenant_id: str
    scopes: frozenset[str] = field(default_factory=frozenset)
    roles: frozenset[str] = field(default_factory=frozenset)
    is_application: bool = False

    def has_any_scope(self, scopes: Iterable[str]) -> bool:
        return bool(self.scopes.intersection(scopes))

    def has_any_role(self, roles: Iterable[str]) -> bool:
        return bool(self.roles.intersection(roles))


class TokenValidator:
    def __init__(
        self,
        tenant_id: str,
        audience: str,
        *,
        key_resolver: SigningKeyResolver | None = None,
        leeway_seconds: int = 60,
    ) -> None:
        if not tenant_id or not audience:
            raise ValueError("tenant_id and audience are required")
        self.tenant_id = tenant_id
        self.audience = audience
        self.issuer = f"https://login.microsoftonline.com/{tenant_id}/v2.0"
        self.leeway = leeway_seconds
        self._keys: SigningKeyResolver = key_resolver or jwt.PyJWKClient(
            f"https://login.microsoftonline.com/{tenant_id}/discovery/v2.0/keys",
            cache_keys=True,
            lifespan=3600,
        )

    def validate(self, token: str) -> Principal:
        try:
            signing_key = self._keys.get_signing_key_from_jwt(token)
            claims: dict[str, Any] = jwt.decode(
                token,
                key=signing_key.key,
                algorithms=ALLOWED_ALGORITHMS,
                audience=self.audience,
                issuer=self.issuer,
                leeway=self.leeway,
                options={"require": ["exp", "iat", "nbf", "iss", "aud", "sub", "tid"]},
            )
        except jwt.PyJWTError as exc:  # do not leak validation details to clients
            raise AuthError("invalid token") from exc

        if claims.get("tid") != self.tenant_id:
            raise AuthError("token from unexpected tenant")

        scopes = frozenset(str(claims.get("scp", "")).split())
        roles = frozenset(claims.get("roles", []) or [])
        return Principal(
            subject=str(claims.get("oid") or claims["sub"]),
            tenant_id=str(claims["tid"]),
            scopes=scopes,
            roles=roles,
            is_application=not scopes and bool(roles),
        )


def authorize(principal: Principal, *, scopes: Iterable[str] = (), roles: Iterable[str] = ()) -> None:
    """Allow if the principal holds ANY of the delegated scopes or ANY of the app roles."""
    scopes, roles = tuple(scopes), tuple(roles)
    if principal.has_any_scope(scopes) or principal.has_any_role(roles):
        return
    raise ForbiddenError("insufficient permissions")


LOCAL_DEV_PRINCIPAL = Principal(
    subject="00000000-0000-0000-0000-00000000dev0",
    tenant_id="local",
    scopes=frozenset({"Policies.ReadWrite", "Claims.Submit"}),
    roles=frozenset({"Underwriter", "Adjuster"}),
)
