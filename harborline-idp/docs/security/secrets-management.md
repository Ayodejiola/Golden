# Secrets management standard

**Default: there is no secret.** Prefer, in order:

1. **Federation** — workload identity (pods), GitHub OIDC (CI), Entra auth (PostgreSQL, Service Bus, Storage, ACR).
2. **Platform-managed certificates** — Key Vault certificates consumed by App Gateway and app routing NGINX.
3. **Key Vault secret via CSI driver** — only for third parties that cannot federate (partner API keys, the GitOps
   GitHub App key). Mounted as files under `/mnt/secrets`, rotated by the CSI driver (2-minute poll).

## Rules

| Rule | Enforced by |
|---|---|
| No secrets in Git, images, Helm values, Terraform variables or logs | Gitleaks (pre-commit + CI), Claude guard hook, Trivy secret scan |
| No Service Bus SAS, storage account keys, PostgreSQL passwords, ACR admin | Module defaults + Conftest + Azure Policy |
| Every secret has an owner, a rotation period (≤ 90 days) and an expiry date in Key Vault | Key Vault `expiration_date`, monthly report |
| Secret access is per identity and audited | Key Vault RBAC per workload identity, `AuditEvent` logs to SIEM |
| Exceptions are registered with compensating controls and an end date | [Exceptions process](../governance/exceptions-process.md) |

## Inventory of remaining secrets

| Secret | Location | Consumer | Rotation | Notes |
|---|---|---|---|---|
| `appinsights-connection-string` | platform KV (per env) | OTel Collector | on recreate | Ingestion key, not an auth secret to data; replaced by Entra-authenticated OTLP ingestion when GA |
| `argocd-github-app-private-key` | platform KV | Argo CD (bootstrap) | 90 days | Read-only repo access |
| `backstage-db-password` | platform KV (prod) | Backstage | 90 days | **EXC-0001** |
| `backstage-github-app-*`, `backstage-entra-client-secret`, `backstage-backend-secret` | platform KV (prod) | Backstage | 90 days | Portal integrations |
| `GITOPS_APP_PRIVATE_KEY` | GitHub org secret | `_gitops-update.yml` | 90 days | Can only open PRs |
| `ANTHROPIC_API_KEY` | GitHub org secret | `ai-review.yml` | 90 days | Scoped workspace key, spend limit |

Rotation procedure: [secret and credential rotation runbook](../operations/runbooks/secret-and-credential-rotation.md).
