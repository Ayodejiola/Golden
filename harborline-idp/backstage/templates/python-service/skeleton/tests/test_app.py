import os

os.environ.setdefault("OTEL_SDK_DISABLED", "true")

from fastapi.testclient import TestClient  # noqa: E402

from ${{ values.package }}.main import app  # noqa: E402

client = TestClient(app)


def test_health() -> None:
    assert client.get("/healthz/live").json() == {"status": "ok"}
    assert client.get("/healthz/ready").status_code == 200


def test_hello_truncates_input() -> None:
    r = client.get("/api/v1/hello", params={"name": "x" * 500})
    assert r.status_code == 200 and len(r.json()["message"]) < 80
