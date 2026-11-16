"""Liveness/readiness probes (golden-path contract: /healthz/live and /healthz/ready)."""

from __future__ import annotations

from fastapi import APIRouter, Request, Response

router = APIRouter(tags=["health"], include_in_schema=False)


@router.get("/healthz/live")
def live() -> dict[str, str]:
    # Liveness must not depend on downstreams, or a DB blip would restart every pod.
    return {"status": "ok"}


@router.get("/healthz/ready")
def ready(request: Request, response: Response) -> dict[str, str]:
    checks = {"database": "ok", "outbox": "ok"}
    try:
        request.app.state.repo.ping()
    except Exception:  # noqa: BLE001
        checks["database"] = "unavailable"
    if not request.app.state.relay.healthy:
        checks["outbox"] = "degraded"  # degraded outbox does not block serving reads
    if checks["database"] != "ok":
        response.status_code = 503
    return checks
