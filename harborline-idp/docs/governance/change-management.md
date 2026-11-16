# Change management

Harborline uses **automated change governance**: the PR is the change record, the pipeline is the approver of record
for standard changes, and evidence is captured automatically.

| Change type | Examples | Approval | Window |
|---|---|---|---|
| **Standard** (pre-approved) | Service release via golden path, add-on patch, Terraform change with no destroys | PR review by code owners + green checks | Any time (prod: Argo CD sync windows apply) |
| **Normal** | Destroys in prod, network/firewall changes, policy relaxations, AKS minor upgrades | PR + Cloud Architecture/Security approver + change ticket in PR title | Business hours, not Friday |
| **Emergency** | Incident mitigation | Incident commander; PR merged with one approval; retro-review within 2 business days | Any time |

## Evidence captured automatically

- Who: PR author, reviewers, merger (GitHub); identity used for apply (Azure activity log).
- What: diff, Terraform plan comment, Conftest results, rendered manifests (k8s-validate).
- When: workflow run timestamps; Argo CD sync history.
- Verification: SLO dashboards and alerts post-deploy; rollback is a revert PR.

## Freeze periods

Year-end and regulatory filing periods are announced by the platform team; during freezes the prod AppProject sync
windows are extended to deny automatic syncs (manual sync remains for incident fixes).
