# ${{ values.name }}

${{ values.description }}

Created from the Harborline **Python API service** golden path. Owner: `${{ values.owner }}`.

## First steps

1. Merge the GitOps PR in `harborline/harborline-idp` after the first `main` build (it sets the image digest).
2. Ask Platform Engineering (or add to `infra/terraform/stacks/workload-${{ values.team }}`) for the workload identity;
   put its client ID in `gitops/workloads/dev/${{ values.team }}/${{ values.name }}/values.yaml`.
3. Write your API in `src/${{ values.package }}/main.py`; keep `/healthz/live` and `/healthz/ready`.

## Local development

```bash
python -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt pytest httpx
OTEL_SDK_DISABLED=true python -m pytest
OTEL_SDK_DISABLED=true uvicorn ${{ values.package }}.main:app --app-dir src --reload --port 8080
```

## What you get for free

- CI: lint, tests, coverage, dependency audit, CodeQL, Trivy, SBOM, Sigstore signing, SLSA provenance.
- CD: digest-pinned GitOps deploy to dev; `promote` workflow for stg/prod.
- Runtime: restricted pod security, workload identity, HPA, PDB, zone spreading, default-deny network policy.
- Observability: OpenTelemetry traces/metrics/logs to Azure Monitor; golden-signals dashboard; SLO alerts.
