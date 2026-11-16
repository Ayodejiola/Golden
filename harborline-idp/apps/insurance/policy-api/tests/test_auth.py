"""Token validation tests with locally generated RSA keys (no network, no real tenant)."""

from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Any

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa

from policy_api.auth import AuthError, ForbiddenError, Principal, TokenValidator, authorize

TENANT = "11111111-2222-3333-4444-555555555555"
AUDIENCE = "api://harborline-policy-api"


@dataclass
class _Key:
    key: Any


class StaticResolver:
    def __init__(self, public_key: Any) -> None:
        self.public_key = public_key

    def get_signing_key_from_jwt(self, token: str) -> _Key:
        return _Key(self.public_key)


@pytest.fixture(scope="module")
def keypair() -> rsa.RSAPrivateKey:
    return rsa.generate_private_key(public_exponent=65537, key_size=2048)


@pytest.fixture
def validator(keypair: rsa.RSAPrivateKey) -> TokenValidator:
    return TokenValidator(TENANT, AUDIENCE, key_resolver=StaticResolver(keypair.public_key()))


def make_token(key: Any, **overrides: Any) -> str:
    now = int(time.time())
    claims = {
        "iss": f"https://login.microsoftonline.com/{TENANT}/v2.0",
        "aud": AUDIENCE,
        "tid": TENANT,
        "sub": "subject-1",
        "oid": "00000000-aaaa-bbbb-cccc-000000000001",
        "iat": now,
        "nbf": now,
        "exp": now + 600,
        "scp": "Policies.ReadWrite",
    }
    claims.update(overrides)
    return jwt.encode(claims, key, algorithm="RS256")


def test_valid_token(validator: TokenValidator, keypair: rsa.RSAPrivateKey) -> None:
    p = validator.validate(make_token(keypair))
    assert p.subject == "00000000-aaaa-bbbb-cccc-000000000001"
    assert "Policies.ReadWrite" in p.scopes
    assert not p.is_application


@pytest.mark.parametrize(
    "override",
    [
        {"aud": "api://someone-else"},
        {"iss": "https://evil.example/v2.0"},
        {"exp": int(time.time()) - 3600},
        {"nbf": int(time.time()) + 3600},
        {"tid": "99999999-0000-0000-0000-000000000000"},
    ],
)
def test_rejects_bad_claims(validator: TokenValidator, keypair: rsa.RSAPrivateKey, override: dict) -> None:
    with pytest.raises(AuthError):
        validator.validate(make_token(keypair, **override))


def test_rejects_wrong_signature(validator: TokenValidator) -> None:
    other = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    with pytest.raises(AuthError):
        validator.validate(make_token(other))


def test_rejects_hs256_confusion(validator: TokenValidator) -> None:
    token = jwt.encode({"aud": AUDIENCE, "tid": TENANT}, "secret-key-that-is-long-enough-123", algorithm="HS256")
    with pytest.raises(AuthError):
        validator.validate(token)


def test_app_roles_token(validator: TokenValidator, keypair: rsa.RSAPrivateKey) -> None:
    p = validator.validate(make_token(keypair, scp="", roles=["Adjuster"]))
    assert p.is_application and "Adjuster" in p.roles


def test_authorize_scope_or_role() -> None:
    user = Principal("u", TENANT, scopes=frozenset({"Claims.Submit"}))
    authorize(user, scopes=["Claims.Submit"], roles=["Adjuster"])
    app = Principal("a", TENANT, roles=frozenset({"Adjuster"}))
    authorize(app, scopes=["Claims.Submit"], roles=["Adjuster"])
    with pytest.raises(ForbiddenError):
        authorize(Principal("x", TENANT, scopes=frozenset({"Other"})), scopes=["Claims.Submit"])
