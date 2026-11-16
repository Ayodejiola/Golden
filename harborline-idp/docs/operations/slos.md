# Service level objectives

SLOs are defined per service tier and implemented as code (`stacks/workload-*/slo.tf`) with multi-window,
multi-burn-rate alerts. Error budgets are measured over a rolling **30 days**.

## Tier defaults

| Tier | Availability SLO | Latency SLO | Paging | DR (RTO / RPO) |
|---|---|---|---|---|
| tier-0 | 99.95% | p99 < 300 ms | 24×7 | 1 h / 5 min |
| tier-1 | 99.9% | p99 < 500 ms | 24×7 | 4 h / 15 min |
| tier-2 | 99.5% | p95 < 1 s | business hours | 24 h / 1 h |
| tier-3 | best effort | — | ticket | 72 h / 24 h |

## Platform SLOs

| Capability | SLI | Objective |
|---|---|---|
| Deploy pipeline | Successful dev deploys / attempts (excluding test failures) | 99% |
| Lead time (merge → dev running) | p90 | < 15 min |
| Argo CD sync | Apps Synced & Healthy | 99.5% of time |
| Kubernetes API (prod) | AKS uptime SLA | 99.95% (Standard tier, AZs) |
| Backstage | Availability | 99.5% business hours |

## Reference app SLOs

| Service | SLI | Objective | Alerts |
|---|---|---|---|
| policy-api | Non-5xx responses / all responses (`http_server_request_duration_seconds_count`) | 99.9% | `PolicyApiAvailabilityFastBurn` (14.4×, 1h & 5m, sev 1), `PolicyApiAvailabilitySlowBurn` (6×, 6h & 30m, sev 2) |
| policy-api | Requests < 500 ms | 99% | `PolicyApiLatencyFastBurn` (sev 2) |
| claims-worker | Claims triaged within 5 min of submission | 99% | planned (GP-11 gap) |

## Error budget policy

| Budget remaining | Action |
|---|---|
| > 50% | Ship freely |
| 25–50% | Prioritise reliability items in the next sprint |
| < 25% | Feature freeze for the service except reliability/security fixes; post-incident reviews mandatory |
| Exhausted | Freeze + SRE engagement; promotion to prod requires SRE approval |
