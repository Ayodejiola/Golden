"""Pure, read-only queries over the Harborline IDP repository (no network, no writes, no secrets).

Every path is resolved inside the repository root; anything outside is refused (prompt-injection and
path-traversal defence for AI clients). Results are plain dicts so any MCP SDK version can serialise them.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml

MAX_BYTES = 512 * 1024
SECRET_FILE = re.compile(r"(\.env|\.tfstate|kubeconfig|\.pem|\.key|\.pfx)$", re.IGNORECASE)


class AccessDenied(ValueError):
    """Requested path is outside the repository or is a secret-bearing file."""


@dataclass(frozen=True)
class Repo:
    root: Path

    @classmethod
    def at(cls, root: str | Path) -> Repo:
        return cls(Path(root).resolve())

    # ---------- safe file access ----------
    def resolve(self, relative: str | Path) -> Path:
        p = (self.root / relative).resolve()
        if p != self.root and self.root not in p.parents:
            raise AccessDenied(f"path escapes repository: {relative}")
        if SECRET_FILE.search(p.name):
            raise AccessDenied(f"refusing to read secret-bearing file: {p.name}")
        return p

    def read(self, relative: str | Path) -> str:
        p = self.resolve(relative)
        if p.stat().st_size > MAX_BYTES:
            raise AccessDenied(f"file too large: {relative}")
        return p.read_text(encoding="utf-8", errors="replace")

    def rel(self, p: Path) -> str:
        return str(p.relative_to(self.root))

    # ---------- catalog ----------
    def catalog_files(self) -> list[Path]:
        files = [self.root / "catalog-info.yaml"]
        root_doc = yaml.safe_load(self.read("catalog-info.yaml")) or {}
        for target in (root_doc.get("spec") or {}).get("targets", []):
            files.append((self.root / target).resolve())
        return [f for f in files if f.exists()]

    def entities(self) -> list[dict[str, Any]]:
        out: list[dict[str, Any]] = []
        for f in self.catalog_files():
            for doc in yaml.safe_load_all(self.read(f.relative_to(self.root))):
                if isinstance(doc, dict) and doc.get("kind") not in (None, "Location"):
                    doc["_source"] = self.rel(f)
                    out.append(doc)
        return out

    def list_services(self) -> list[dict[str, Any]]:
        services = []
        for e in self.entities():
            if e["kind"] != "Component":
                continue
            md, spec = e.get("metadata", {}), e.get("spec", {})
            services.append(
                {
                    "name": md.get("name"),
                    "type": spec.get("type"),
                    "owner": spec.get("owner"),
                    "system": spec.get("system"),
                    "lifecycle": spec.get("lifecycle"),
                    "description": md.get("description", ""),
                    "source": e["_source"],
                }
            )
        return sorted(services, key=lambda s: s["name"] or "")

    def get_service(self, name: str) -> dict[str, Any]:
        match = next((s for s in self.list_services() if s["name"] == name), None)
        if match is None:
            return {"error": f"no component named {name!r}"}
        entity = next(e for e in self.entities() if e.get("metadata", {}).get("name") == name)
        deployments = []
        for values in sorted(self.root.glob(f"gitops/workloads/*/*/{_gitops_app_name(name)}/values.yaml")):
            v = yaml.safe_load(values.read_text()) or {}
            deployments.append(
                {
                    "environment": values.parts[-4],
                    "team": values.parts[-3],
                    "image_tag": (v.get("image") or {}).get("tag"),
                    "digest_pinned": str((v.get("image") or {}).get("digest", "")).startswith("sha256:"),
                    "values_file": self.rel(values),
                }
            )
        return {**match, "annotations": entity.get("metadata", {}).get("annotations", {}), "deployments": deployments}

    # ---------- docs ----------
    def list_adrs(self) -> list[dict[str, str]]:
        adrs = []
        for f in sorted((self.root / "docs" / "adr").glob("[0-9][0-9][0-9][0-9]-*.md")):
            if f.stem.startswith("0000"):
                continue  # template
            text = f.read_text(encoding="utf-8")
            title = next((ln.lstrip("# ").strip() for ln in text.splitlines() if ln.startswith("# ")), f.stem)
            status = re.search(r"\*\*Status:\*\*\s*([A-Za-z]+)", text)
            adrs.append(
                {
                    "id": f.stem[:4],
                    "title": title,
                    "status": status.group(1) if status else "Unknown",
                    "path": self.rel(f),
                }
            )
        return adrs

    def find_runbook(self, query: str, limit: int = 3) -> list[dict[str, Any]]:
        terms = [t for t in re.split(r"[^a-z0-9]+", query.lower()) if len(t) > 2]
        results = []
        for f in (self.root / "docs" / "operations" / "runbooks").glob("*.md"):
            if f.name == "index.md":
                continue
            text = f.read_text(encoding="utf-8")
            lower = text.lower()
            title = next((ln.lstrip("# ").strip() for ln in text.splitlines() if ln.startswith("# ")), f.stem)
            score = sum(lower.count(t) for t in terms) + 5 * sum(t in f.stem for t in terms)
            if score:
                summary = next((p.strip() for p in text.split("\n\n")[1:] if p.strip() and not p.startswith("#")), "")
                alerts = sorted(
                    set(
                        re.findall(
                            r"`([A-Z][A-Za-z]+(?:Burn|NotReady|CrashLooping|Mismatch|OOMKilled|"
                            r"Saturation|FillingUp|High|OutOfSync|Backlog|Expiry|Denied))`",
                            text,
                        )
                    )
                )
                results.append(
                    {"title": title, "path": self.rel(f), "score": score, "summary": summary[:400], "alerts": alerts}
                )
        return sorted(results, key=lambda r: -r["score"])[:limit]

    def golden_path_requirements(self) -> list[dict[str, str]]:
        text = self.read("docs/governance/golden-path.md")
        section = text.split("## Requirements", 1)[-1].split("\n## ", 1)[0]
        reqs = []
        for line in section.splitlines():
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) >= 3 and re.match(r"^GP-\d+", cells[0]):
                reqs.append({"id": cells[0], "requirement": cells[1], "enforced_by": cells[2]})
        return reqs

    # ---------- golden path validation ----------
    def validate_service(self, path: str) -> dict[str, Any]:
        svc = self.resolve(path)
        if not svc.is_dir():
            raise AccessDenied(f"not a directory inside the repository: {path}")
        findings: list[dict[str, str]] = []

        def check(req: str, ok: bool, evidence: str) -> None:
            findings.append({"requirement": req, "status": "pass" if ok else "fail", "evidence": evidence})

        dockerfile = svc / "Dockerfile"
        if dockerfile.exists():
            d = dockerfile.read_text()
            check("GP-03 multi-stage build", d.count("FROM ") >= 2, self.rel(dockerfile))
            user = re.findall(r"^USER\s+(\S+)", d, re.MULTILINE)
            check(
                "GP-03 non-root runtime user", bool(user) and user[-1] not in {"root", "0", "0:0"}, self.rel(dockerfile)
            )
        else:
            check("GP-03 Dockerfile present", False, "missing Dockerfile")

        code = "\n".join(p.read_text(errors="ignore") for p in svc.rglob("*.py") if p.stat().st_size < MAX_BYTES)
        check("GP-05 /healthz/live and /healthz/ready", "/healthz/live" in code and "/healthz/ready" in code, "source")
        check("GP-06 OpenTelemetry initialised", "opentelemetry" in code, "source")
        check("GP-07 no print() logging", not re.search(r"^\s*print\(", code, re.MULTILINE), "source")

        tests = list(svc.rglob("test_*.py"))
        check("GP-04 unit tests present", bool(tests), f"{len(tests)} test files")

        catalog = svc / "catalog-info.yaml"
        parent_catalog = svc.parent / "catalog-info.yaml"
        cat_file = catalog if catalog.exists() else parent_catalog if parent_catalog.exists() else None
        if cat_file:
            docs = [d for d in yaml.safe_load_all(cat_file.read_text()) if isinstance(d, dict)]
            comp = next(
                (
                    d
                    for d in docs
                    if d.get("kind") == "Component"
                    and d["metadata"]["name"] in {svc.name, svc.name.replace("-web", "")}
                ),
                docs[0] if docs else {},
            )
            spec = comp.get("spec", {})
            check(
                "GP-01 catalog owner/system/lifecycle",
                all(spec.get(k) for k in ("owner", "system", "lifecycle")),
                self.rel(cat_file),
            )
        else:
            check("GP-01 catalog-info.yaml", False, "missing catalog-info.yaml")

        values = sorted(self.root.glob(f"gitops/workloads/*/*/{svc.name}/values.yaml"))
        check("GP-09 deployed via GitOps values", bool(values), ", ".join(self.rel(v) for v in values) or "none")
        for v in values:
            data = yaml.safe_load(v.read_text()) or {}
            check(
                f"GP-10 digest-pinned image ({v.parts[-4]})",
                re.fullmatch(r"sha256:[a-f0-9]{64}", str((data.get("image") or {}).get("digest", ""))) is not None,
                self.rel(v),
            )
        passed = sum(f["status"] == "pass" for f in findings)
        return {"service": self.rel(svc), "score": f"{passed}/{len(findings)}", "findings": findings}


def _gitops_app_name(component: str) -> str:
    return "web" if component == "policy-portal-web" else component
