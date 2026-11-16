# Service scorecards

Scorecards make the golden path measurable. Each service is scored against the [GP requirements](golden-path.md)
plus operational hygiene. Results are shown in Backstage and reviewed monthly by each team; the platform team reviews
aggregate trends to decide what to automate next.

| Level | Criteria |
|---|---|
| 🥉 Bronze | GP-01, GP-02, GP-03, GP-05, GP-09 |
| 🥈 Silver | Bronze + GP-04, GP-06, GP-07, GP-08, GP-10 |
| 🥇 Gold | Silver + GP-11, GP-12, GP-13, zero overdue vulnerabilities, last DR test < 6 months |

**Production entry criteria:** tier-0/1 services must be Gold; tier-2 Silver; tier-3 Bronze.

## How scores are computed

- `platform-catalog` MCP `validate_service` and the same checks in CI compute GP-01..GP-10 from the repository.
- GP-11/12 come from catalog annotations and Terraform SLO definitions.
- Vulnerability and DR criteria come from Defender for Cloud and the DR test log.

Run locally:

```bash
claude  # then: /golden-path-check apps/insurance/policy-api
```

## Current state (reference app)

| Service | Level | Gaps |
|---|---|---|
| policy-api | 🥇 Gold | — |
| claims-worker | 🥈 Silver | GP-11 (worker SLO on triage latency to be added) |
| web | 🥈 Silver | GP-11 (synthetic availability probe planned) |
