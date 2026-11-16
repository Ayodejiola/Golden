# Platform metrics

## North star

**Lead time from first commit to production for a new service** (target: < 5 working days).

## DORA (per team and aggregate)

| Metric | Source | Target (elite) |
|---|---|---|
| Deployment frequency | Merged `deploy:` PRs to `gitops/workloads/prod` | On demand (daily+) |
| Lead time for changes | Commit timestamp → prod GitOps PR merge | < 1 day |
| Change failure rate | Prod deploys followed by rollback PR or linked incident | < 15% |
| Time to restore | Incident open → resolved | < 1 hour |

## Adoption and experience

| Metric | Source | Target |
|---|---|---|
| Services on golden path (GP Silver+) | Scorecards | 80% by end of year |
| Time to first dev deploy (new service) | Template run → first Argo CD sync | < 1 hour |
| Developer NPS / satisfaction | Quarterly survey (SPACE-inspired) | > +30 |
| Platform tickets per team per month | Issue tracker | Decreasing |
| AI-assisted PR share and their change failure rate | Commit trailers + DORA | Tracked (no target) |

## Control coverage

| Metric | Source |
|---|---|
| % images signed and verified at admission | Kyverno policy reports |
| % workloads using workload identity | Catalog + chart values |
| Open policy exceptions / overdue | Exceptions register |
| Vulnerability MTTR by severity | Defender + code scanning |
| Azure Policy compliance % per subscription | Defender for Cloud |
