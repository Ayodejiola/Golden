# Getting started (product engineers)

Time needed: about an hour for your first service in dev.

## 1. Prerequisites

- Member of your team's Entra group (e.g. `grp-insurance-digital-engineers`) and `grp-all-engineers`.
- GitHub org membership (`harborline`) with SSO; Claude Code enterprise seat (optional but recommended).
- Tools: `az`, `kubectl` + `kubelogin`, `git`, Python 3.12 or Node 22, Docker.

## 2. Make sure your team has a tenant

Backstage → **Catalog** → your group. If there is no namespace yet, run **Create → Tenant onboarding**.
Platform Engineering reviews the PR (usually same day).

## 3. Create a service

Backstage → **Create → Python API service**. Choose owner, system, tier and data classification. You get:

- `harborline/<name>` repository with CI, tests, Dockerfile, docs and catalog entry,
- a PR in `harborline-idp` adding `gitops/workloads/dev/<team>/<name>/values.yaml`.

## 4. First deploy

1. Push a change to `main` in your repo (or merge the initial PR). CI tests, scans, builds, signs and opens a GitOps PR
   with the image digest; it auto-merges for dev.
2. Merge the onboarding PR in `harborline-idp` (after the first digest lands).
3. Watch it: Backstage → your component → **Kubernetes** tab, or Argo CD (`https://argocd.dev.harborline.example`).

## 5. Observe

Grafana → *Harborline / Service golden signals* → select your service. Traces are in Application Insights
(`appi-plat-dev-cac-01`). Define SLOs by adding your service to `slo.tf` in your workload stack.

## 6. Need Azure resources?

Copy the patterns in `infra/terraform/stacks/workload-insurance` (PostgreSQL, Service Bus, workload identities) into
`workload-<team>` via PR. Put the identity client ID into your values file and set `workloadIdentity.enabled: true`.

## 7. Promote

GitHub → Actions → **promote** → choose app and `from: dev` (then `from: stg`). Production requires a change ticket
and code-owner approval.

## Using Claude Code

Open the repo in Claude Code; `CLAUDE.md` and the guardrails load automatically. Try `/golden-path-check .` or ask
*"who owns policy-api and where is it deployed?"* (answered by the `platform-catalog` MCP server). Read the
[usage policy](ai/usage-policy.md) first.
