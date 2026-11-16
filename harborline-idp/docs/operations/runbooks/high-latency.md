# High latency (latency SLO burn)

| | |
|---|---|
| **Alerts / trigger** | `PolicyApiLatencyFastBurn` |
| **Owner** | Owning team |

p99 latency exceeds the SLO threshold (500 ms for policy-api) fast enough to threaten the error budget.

## Diagnose (read-only)

```bash
kubectl -n <ns> top pods -l app.kubernetes.io/name=<app>
kubectl -n <ns> get hpa <app>
# App Insights (KQL): slowest dependencies
# dependencies | where timestamp > ago(30m) | summarize p95=percentile(duration,95), n=count() by target, name | top 10 by p95
```

## Mitigate

1. Open a slow trace in Application Insights (end-to-end transaction) to find the slow span.
2. Database-bound: see [connection saturation](postgres-connection-saturation.md).
3. CPU-bound: check throttling and HPA limits; scale out; check node saturation.
4. Regression after a deploy: roll back.

## Verify

p99 under the threshold for 30 minutes; alert resolved.

## Escalate

Page the next tier in [on-call](../oncall.md) if not mitigated within 30 minutes (SEV1) or 2 hours (SEV2). Record
actions in the incident timeline.
