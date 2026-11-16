"""PII minimisation helpers. Logs, traces and events must never carry raw policyholder PII (ASVS V14, V16)."""

from __future__ import annotations

import hashlib
import hmac
import os
import re
from typing import Any

_EMAIL = re.compile(r"([A-Za-z0-9._%+-])[A-Za-z0-9._%+-]*@([A-Za-z0-9.-]+\.[A-Za-z]{2,})")
_SIN = re.compile(r"\b\d{3}[- ]?\d{3}[- ]?\d{3}\b")
_CARD = re.compile(r"\b(?:\d[ -]?){13,16}\b")
_PHONE = re.compile(r"\b(?:\+?1[ -.]?)?\(?\d{3}\)?[ -.]?\d{3}[ -.]?\d{4}\b")

SENSITIVE_KEYS = frozenset(
    {"first_name", "last_name", "email", "date_of_birth", "phone", "address", "postal_code", "description", "sin"}
)


def mask(text: str) -> str:
    """Mask emails, SIN-, card- and phone-shaped numbers in free text."""
    text = _EMAIL.sub(r"\1***@\2", text)
    text = _CARD.sub("[CARD]", text)
    text = _SIN.sub("[SIN]", text)
    text = _PHONE.sub("[PHONE]", text)
    return text


def redact(data: Any) -> Any:
    """Recursively replace values of sensitive keys; mask strings elsewhere."""
    if isinstance(data, dict):
        return {k: ("[REDACTED]" if k in SENSITIVE_KEYS else redact(v)) for k, v in data.items()}
    if isinstance(data, list):
        return [redact(v) for v in data]
    if isinstance(data, str):
        return mask(data)
    return data


def pseudonymise(value: str, *, key: bytes | None = None) -> str:
    """Stable keyed hash for correlating a subject across telemetry without revealing it."""
    secret = key or os.environ.get("PSEUDONYMISATION_KEY", "harborline-local-only").encode()
    return hmac.new(secret, value.strip().lower().encode(), hashlib.sha256).hexdigest()[:16]
