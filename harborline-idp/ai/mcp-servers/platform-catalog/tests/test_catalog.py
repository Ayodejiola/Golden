from __future__ import annotations

import asyncio
from pathlib import Path

import pytest

from catalog import AccessDenied, Repo

ROOT = Path(__file__).resolve().parents[4]


@pytest.fixture(scope="module")
def repo() -> Repo:
    return Repo.at(ROOT)


def test_lists_reference_services(repo: Repo) -> None:
    names = {s["name"] for s in repo.list_services()}
    assert {"policy-api", "claims-worker", "policy-portal-web", "harborline-idp"} <= names
    api = next(s for s in repo.list_services() if s["name"] == "policy-api")
    assert api["owner"] == "group:default/insurance-digital"


def test_get_service_includes_deployments(repo: Repo) -> None:
    svc = repo.get_service("policy-api")
    envs = {d["environment"] for d in svc["deployments"]}
    assert envs == {"dev", "stg", "prod"}
    assert all(d["digest_pinned"] for d in svc["deployments"])


def test_unknown_service(repo: Repo) -> None:
    assert "error" in repo.get_service("does-not-exist")


def test_find_runbook_for_alert(repo: Repo) -> None:
    hits = repo.find_runbook("dead letter messages service bus")
    assert hits and "dead" in hits[0]["path"]


def test_adrs_have_status(repo: Repo) -> None:
    adrs = repo.list_adrs()
    assert len(adrs) >= 15
    assert all(a["status"] in {"Accepted", "Proposed", "Superseded", "Deprecated"} for a in adrs)


def test_golden_path_requirements(repo: Repo) -> None:
    reqs = repo.golden_path_requirements()
    assert reqs and all(r["id"].startswith("GP-") for r in reqs)


def test_validate_reference_service_passes(repo: Repo) -> None:
    result = repo.validate_service("apps/insurance/policy-api")
    failed = [f for f in result["findings"] if f["status"] == "fail"]
    assert not failed, failed


@pytest.mark.parametrize("path", ["../../etc", "/etc", "apps/../../.."])
def test_path_traversal_refused(repo: Repo, path: str) -> None:
    with pytest.raises(AccessDenied):
        repo.validate_service(path)


def test_secret_files_refused(repo: Repo) -> None:
    with pytest.raises(AccessDenied):
        repo.read("infra/terraform/stacks/platform/terraform.tfstate")


def test_server_registers_read_only_tools() -> None:
    from server import build_server

    server = build_server(ROOT)
    tools = asyncio.run(server.list_tools())
    names = {t.name for t in tools}
    assert names == {
        "list_services",
        "get_service",
        "find_runbook",
        "list_adrs",
        "get_golden_path_requirements",
        "validate_service",
    }
    for t in tools:
        if t.annotations is not None:  # SDK 1.x uses camelCase attributes, 2.x snake_case
            hint = getattr(t.annotations, "read_only_hint", None)
            if hint is None:
                hint = getattr(t.annotations, "readOnlyHint", None)
            assert hint is True
