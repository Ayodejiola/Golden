# Deployment guide (platform team)

Stand up the platform in a new Azure tenant. Assumes the enterprise ALZ core (management groups, global policies)
exists or will be deployed with the ALZ accelerator.

## 0. Prerequisites

| Item | Detail |
|---|---|
| Subscriptions | management, connectivity, lz-dev, lz-stg, lz-prod (placed in the right management groups) |
| Entra groups | platform admins, all engineers, team groups, DBA groups (object IDs into tfvars) |
| GitHub | Enterprise Cloud org `harborline`, GitHub App for GitOps PRs and Argo CD, environments `shared`, `dev`, `stg`, `prod` (reviewers on `stg`, `prod`, `shared`) |
| Feature registration | `Microsoft.Compute/EncryptionAtHost`, `GitHub.Network` resource provider |
| DNS / certificates | Public zone for `harborline.example`, TLS certificates for portal and internal wildcard |

Replace placeholders: `grep -rn "00000000-0000-0000-0000" infra gitops backstage`.

## 1. State and CI identities (Cloud Admin, once)

```bash
scripts/bootstrap-state.sh <management-subscription-id>
cd infra/terraform/stacks/bootstrap
terraform init -backend-config=env/shared.backend.hcl
terraform apply -var-file=env/shared.tfvars
terraform output github_client_ids
```

Set GitHub variables: `AZURE_TENANT_ID`, `MANAGEMENT_SUBSCRIPTION_ID`, `ACR_PUSH_CLIENT_ID`,
`TF_PLAN_CLIENT_ID_<ENV>` (repo level) and `AZURE_CLIENT_ID` + `AZURE_SUBSCRIPTION_ID` per GitHub environment.
Secrets: `GITOPS_APP_ID`, `GITOPS_APP_PRIVATE_KEY`, `ONCALL_WEBHOOK_URL`, `ANTHROPIC_API_KEY` (optional).

## 2. Shared platform (pipeline)

Merge a PR touching `infra/terraform/stacks/management` and `connectivity` → `terraform.yml` applies `management`
then `connectivity` after `shared` environment approval. Then:

- Add a blob private endpoint for the state account in the hub and disable its public access.
- Run `mirror-artifacts.yml` to populate ACR with Argo CD, Kyverno, OTel images and charts.

## 3. Environments (pipeline)

1. Import TLS certificates into each platform Key Vault (`portal-tls`, `wildcard-internal`).
2. `terraform.yml` applies `platform` and `workload-insurance` for dev → stg → prod.
3. Register `github_network_settings_id` outputs in GitHub hosted-compute networking; create runner groups
   `harborline-build`, `harborline-dev`, `harborline-stg`, `harborline-prod` (set `github_business_id` and re-apply).
4. Copy Terraform outputs into GitOps values (identity client IDs, ingress IP) — `make` target or manual PR.

## 4. Bootstrap Argo CD

Store the Argo CD GitHub App ID, installation ID and private key in each platform Key Vault
(`argocd-github-app-*`). Run **Actions → platform-bootstrap** for `dev`, then `stg`, then `prod`. Argo CD installs
add-ons, policies, tenants and workloads from `gitops/clusters/<env>`.

## 5. Developer portal

Create the Backstage Entra app registration (redirect `https://backstage.harborline.example/api/auth/microsoft/handler/frame`,
Graph `User.Read.All`, `GroupMember.Read.All`) and the Backstage GitHub App; store secrets in the prod platform Key Vault
(names in `gitops/addons/platform-config/overlays/prod/backstage.yaml`). Run `backstage.yml` and update the image tag
in `gitops/addons/backstage/values.yaml`.

## 6. Verify

| Check | How |
|---|---|
| Policies enforced | `kubectl run test --image=nginx -n insurance` is denied (registry, digest, signature) |
| Egress controlled | `curl https://example.com` from a debug pod in dev times out; firewall deny log entry |
| Workloads healthy | Argo CD all Synced/Healthy; `https://portal.dev.harborline.example/api/v1/...` with a token |
| Telemetry | Golden-signals dashboard shows traffic; traces in App Insights |
| Alerts | Fire a test alert (scale a deployment to 0 in dev) and confirm routing |
| Drift detection | `drift-detection.yml` run is green |

## 7. Hand-over

Enable branch protection rulesets (2 reviews, code owners, signed commits, required checks), pin actions
(`make pin-actions`), generate lock files (`make lock`), and schedule the first DR test.
