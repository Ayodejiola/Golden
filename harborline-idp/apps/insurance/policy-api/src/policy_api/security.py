"""FastAPI glue for authentication/authorisation and HTTP security headers."""

from __future__ import annotations

from collections.abc import Awaitable, Callable, Iterable

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

from .auth import LOCAL_DEV_PRINCIPAL, AuthError, Principal, TokenValidator, authorize

bearer = HTTPBearer(auto_error=False)


def get_principal(
    request: Request,
    creds: HTTPAuthorizationCredentials | None = Depends(bearer),  # noqa: B008
) -> Principal:
    settings = request.app.state.settings
    if not settings.auth_required:  # only possible locally (Settings.validate)
        return LOCAL_DEV_PRINCIPAL
    if creds is None or creds.scheme.lower() != "bearer":
        raise AuthError("missing bearer token")
    validator: TokenValidator = request.app.state.token_validator
    return validator.validate(creds.credentials)


def require(*, scopes: Iterable[str] = (), roles: Iterable[str] = ()) -> Callable[..., Principal]:
    scopes_t, roles_t = tuple(scopes), tuple(roles)

    def _dep(principal: Principal = Depends(get_principal)) -> Principal:  # noqa: B008
        authorize(principal, scopes=scopes_t, roles=roles_t)
        return principal

    return _dep


SECURITY_HEADERS = {
    "Cache-Control": "no-store",
    "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "Cross-Origin-Resource-Policy": "same-origin",
}


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable[[Request], Awaitable[Response]]) -> Response:
        response = await call_next(request)
        for k, v in SECURITY_HEADERS.items():
            response.headers.setdefault(k, v)
        return response
