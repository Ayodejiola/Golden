from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Path, Request, status

from ..auth import Principal
from ..models import BindRequest, Policy
from ..security import require
from ..telemetry import POLICIES_BOUND, current_traceparent

router = APIRouter(tags=["policies"])
ReadWrite = require(scopes=["Policies.ReadWrite"], roles=["Underwriter"])


@router.post("/policies", response_model=Policy, status_code=status.HTTP_201_CREATED)
def bind(body: BindRequest, request: Request, principal: Principal = Depends(ReadWrite)) -> Policy:  # noqa: B008
    row = request.app.state.repo.bind_policy(body.quote_id, principal.subject, current_traceparent())
    if row is None:
        # Same response for "not yours", "missing", "expired", "not bindable": no object enumeration (ASVS V8).
        raise HTTPException(status_code=409, detail="quote cannot be bound")
    POLICIES_BOUND.add(1, {"product": row["product"]})
    return Policy(**row)


@router.get("/policies", response_model=list[Policy])
def list_policies(request: Request, principal: Principal = Depends(ReadWrite)) -> list[Policy]:  # noqa: B008
    return [Policy(**r) for r in request.app.state.repo.list_policies(principal.subject)]


@router.get("/policies/{policy_number}", response_model=Policy)
def get_policy(
    request: Request,
    policy_number: str = Path(pattern=r"^HBL-(AU|HO)-\d{4}-\d{6}$"),
    principal: Principal = Depends(ReadWrite),  # noqa: B008
) -> Policy:
    row = request.app.state.repo.get_policy(policy_number, principal.subject)
    if row is None:
        raise HTTPException(status_code=404, detail="not found")
    return Policy(**row)
