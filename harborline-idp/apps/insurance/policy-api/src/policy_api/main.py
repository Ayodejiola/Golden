"""Application factory and entrypoint (uvicorn)."""

from __future__ import annotations

import logging
import uuid
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from . import __version__
from .auth import AuthError, ForbiddenError, TokenValidator
from .config import Settings
from .logging_config import configure_logging
from .routers import claims, health, policies, quotes
from .security import SecurityHeadersMiddleware
from .telemetry import register_outbox_gauge, setup_telemetry

log = logging.getLogger("policy_api")


def problem(status: int, title: str, request: Request, detail: str | None = None) -> JSONResponse:
    return JSONResponse(
        status_code=status,
        media_type="application/problem+json",
        content={
            "type": "about:blank",
            "title": title,
            "status": status,
            "detail": detail,
            "correlation_id": getattr(request.state, "correlation_id", None),
        },
    )


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings: Settings = app.state.settings
    from .db import create_pool
    from .messaging import ServiceBusPublisher
    from .outbox import OutboxRelay
    from .repository import Repository

    pool = create_pool(settings)
    repo = Repository(pool)
    app.state.repo = repo
    relay = OutboxRelay(
        pool,
        repo,
        ServiceBusPublisher(settings),
        poll_seconds=settings.outbox_poll_seconds,
        topics={"claim": settings.claims_topic, "policy": settings.policies_topic},
    )
    app.state.relay = relay
    register_outbox_gauge(repo.pending_outbox)
    relay.start()
    log.info("policy-api started", extra={"version": __version__})
    try:
        yield
    finally:
        relay.stop()
        pool.close()
        log.info("policy-api stopped")


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or Settings.from_env()
    configure_logging("policy-api", settings.environment, settings.log_level)
    app = FastAPI(
        title="Harborline Policy API",
        version=__version__,
        lifespan=lifespan,
        docs_url="/api/docs" if settings.is_local else None,  # no interactive docs outside local
        redoc_url=None,
        openapi_url="/api/openapi.json",
    )
    app.state.settings = settings
    if settings.auth_required:
        app.state.token_validator = TokenValidator(settings.auth_tenant_id, settings.auth_audience)

    app.add_middleware(SecurityHeadersMiddleware)

    @app.middleware("http")
    async def correlation(request: Request, call_next):  # type: ignore[no-untyped-def]
        cid = request.headers.get("x-correlation-id", "")
        request.state.correlation_id = cid if cid and len(cid) <= 64 and cid.isascii() else str(uuid.uuid4())
        response = await call_next(request)
        response.headers["x-correlation-id"] = request.state.correlation_id
        return response

    @app.exception_handler(AuthError)
    async def _auth(request: Request, exc: AuthError) -> JSONResponse:
        resp = problem(401, "Unauthorized", request)
        resp.headers["WWW-Authenticate"] = "Bearer"
        return resp

    @app.exception_handler(ForbiddenError)
    async def _forbidden(request: Request, exc: ForbiddenError) -> JSONResponse:
        return problem(403, "Forbidden", request)

    @app.exception_handler(StarletteHTTPException)
    async def _http(request: Request, exc: StarletteHTTPException) -> JSONResponse:
        titles = {404: "Not Found", 409: "Conflict", 422: "Unprocessable Content", 405: "Method Not Allowed"}
        return problem(exc.status_code, titles.get(exc.status_code, "Error"), request, str(exc.detail))

    @app.exception_handler(RequestValidationError)
    async def _validation(request: Request, exc: RequestValidationError) -> JSONResponse:
        # Return field paths and messages only — never echo submitted values (may contain PII).
        details = "; ".join(f"{'.'.join(str(p) for p in e['loc'][1:])}: {e['msg']}" for e in exc.errors())
        return problem(422, "Validation failed", request, details[:1000])

    @app.exception_handler(Exception)
    async def _unhandled(request: Request, exc: Exception) -> JSONResponse:
        log.exception("unhandled error", extra={"correlation_id": getattr(request.state, "correlation_id", None)})
        return problem(500, "Internal Server Error", request)

    app.include_router(health.router)
    app.include_router(quotes.router, prefix="/api/v1")
    app.include_router(policies.router, prefix="/api/v1")
    app.include_router(claims.router, prefix="/api/v1")
    setup_telemetry(app)
    return app


def run() -> None:
    import uvicorn

    settings = Settings.from_env()
    uvicorn.run(
        create_app(settings),
        host="0.0.0.0",  # noqa: S104 - container network namespace; NetworkPolicy restricts peers
        port=settings.port,
        proxy_headers=True,
        forwarded_allow_ips="*",
        access_log=False,
        server_header=False,
    )


if __name__ == "__main__":
    run()
