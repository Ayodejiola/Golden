# Software templates

| Template | Creates | Opens PRs in | Typical time |
|---|---|---|---|
| **Python API service** (`python-api-service`) | New repo `harborline/<name>` with FastAPI app, tests, Dockerfile, CI calling the trusted builder, TechDocs, catalog entry, CODEOWNERS, branch protection, `TEAM` repo variable | `harborline-idp`: `gitops/workloads/dev/<team>/<name>/` | 2 minutes |
| **Tenant onboarding** (`tenant-onboarding`) | Namespace, quota, limits, default-deny, RBAC to Entra group, Argo CD AppProject, dev debug access | `harborline-idp`: `gitops/tenants/<team>/` | 1 minute + review |
| **ADR** (`architecture-decision-record`) | ADR from the standard template | `harborline-idp`: `docs/adr/` | 1 minute |

## Template design rules

1. Templates **never** write directly to shared repos or Azure — they open PRs so humans and CI review changes.
2. Generated repos call reusable workflows from `harborline-idp` (`@main`), so security improvements reach every
   service without regenerating.
3. Parameters are validated (patterns, enums) and map to golden-path requirements (GP-01, GP-02).
4. Workflow files are copied without templating (`copyWithoutTemplating`) to avoid `${{ }}` collisions.

## Adding a template

Create `backstage/templates/<name>/template.yaml` + `skeleton/`, register it in the root `catalog-info.yaml`, validate
with the Backstage entity validator (`backstage.yml` workflow) and dry-run in the portal (*Create → Template editor*).
