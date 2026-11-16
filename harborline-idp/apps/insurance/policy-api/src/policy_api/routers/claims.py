from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Path, Request, status

from ..auth import Principal
from ..models import Claim, ClaimRequest
from ..security import require
from ..telemetry import CLAIMS_SUBMITTED, current_traceparent

router = APIRouter(tags=["claims"])
Submit = require(scopes=["Claims.Submit", "Policies.ReadWrite"], roles=["Adjuster"])


@router.post("/claims", response_model=Claim, status_code=status.HTTP_201_CREATED)
def submit_claim(body: ClaimRequest, request: Request, principal: Principal = Depends(Submit)) -> Claim:  # noqa: B008
    try:
        row = request.app.state.repo.submit_claim(body, principal.subject, current_traceparent())
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    if row is None:
        raise HTTPException(status_code=404, detail="policy not found or not active")
    CLAIMS_SUBMITTED.add(1, {"loss_type": body.loss_type.value})
    return Claim(**row)


@router.get("/claims/{claim_number}", response_model=Claim)
def get_claim(
    request: Request,
    claim_number: str = Path(pattern=r"^CLM-\d{4}-\d{7}$"),
    principal: Principal = Depends(Submit),  # noqa: B008
) -> Claim:
    row = request.app.state.repo.get_claim(claim_number, principal.subject)
    if row is None:
        raise HTTPException(status_code=404, detail="not found")
    return Claim(**row)
