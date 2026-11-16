from __future__ import annotations

from fastapi import APIRouter, Depends, Request, status

from ..auth import Principal
from ..models import Quote, QuoteRequest
from ..rating import rate
from ..security import require
from ..telemetry import QUOTES_ISSUED, tracer

router = APIRouter(tags=["quotes"])


@router.post("/quotes", response_model=Quote, status_code=status.HTTP_201_CREATED)
def create_quote(
    body: QuoteRequest,
    request: Request,
    principal: Principal = Depends(require(scopes=["Policies.ReadWrite"], roles=["Underwriter"])),  # noqa: B008
) -> Quote:
    with tracer.start_as_current_span("rating.rate") as span:
        span.set_attribute("insurance.product", body.product.value)
        result = rate(body)
        span.set_attribute("insurance.quote.status", result.status.value)
    row = request.app.state.repo.create_quote(body, result, principal.subject)
    QUOTES_ISSUED.add(1, {"product": body.product.value, "status": result.status.value})
    return Quote(
        id=row["id"],
        product=body.product,
        status=result.status,
        premium=result.premium,
        reasons=result.reasons,
        expires_at=row["expires_at"],
    )
