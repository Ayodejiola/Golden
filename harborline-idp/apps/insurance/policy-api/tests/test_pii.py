from __future__ import annotations

import json
import logging

from policy_api.logging_config import JsonFormatter
from policy_api.pii import mask, pseudonymise, redact


def test_mask_email_sin_card_phone() -> None:
    text = "contact avery@example.com sin 123-456-789 card 4111 1111 1111 1111 phone (506) 555-0199"
    out = mask(text)
    assert "avery@example.com" not in out and "a***@example.com" in out
    assert "123-456-789" not in out
    assert "4111" not in out
    assert "555-0199" not in out


def test_redact_nested_structures() -> None:
    data = {"insured": {"first_name": "Avery", "email": "a@b.co"}, "items": [{"description": "x" * 12}], "n": 3}
    out = redact(data)
    assert out["insured"]["first_name"] == "[REDACTED]"
    assert out["items"][0]["description"] == "[REDACTED]"
    assert out["n"] == 3


def test_pseudonymise_is_stable_and_keyed() -> None:
    a = pseudonymise("Avery@Example.com", key=b"k1")
    assert a == pseudonymise("avery@example.com ", key=b"k1")
    assert a != pseudonymise("avery@example.com", key=b"k2")
    assert len(a) == 16


def test_json_log_masks_message_and_extras() -> None:
    fmt = JsonFormatter("policy-api", "test")
    record = logging.LogRecord("t", logging.INFO, __file__, 1, "quote for avery@example.com", None, None)
    record.customer = "jordan@example.com"
    payload = json.loads(fmt.format(record))
    assert "avery@example.com" not in payload["message"]
    assert "jordan@example.com" not in payload["customer"]
    assert payload["service.name"] == "policy-api"
