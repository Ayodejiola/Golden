# PostgreSQL CPU / connection saturation

| | |
|---|---|
| **Alerts / trigger** | `alert-psql-*-cpu`, `alert-psql-*-memory` |
| **Owner** | Owning team |

High CPU or memory on the database usually comes from a new query plan, a missing index, or connection storms after scaling.

## Diagnose (read-only)

```bash
-- run as a PIM-elevated Entra admin via Bastion
SELECT pid, usename, application_name, state, now() - query_start AS age, left(query, 120)
FROM pg_stat_activity WHERE state <> 'idle' ORDER BY age DESC LIMIT 20;
SELECT queryid, calls, mean_exec_time, left(query, 120) FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10;
SELECT application_name, count(*) FROM pg_stat_activity GROUP BY 1;
```

## Mitigate

1. Identify the top query (`pg_stat_statements`) and correlate with the latest deploy (Argo CD history).
2. Roll back the deploy if a new query regressed; add an index via a migration.
3. Connection storms: reduce pool `max_size` or HPA max; connections per replica × replicas must stay below the server maximum.
4. Scale compute (SKU) via a Terraform PR as a last resort; it causes a short restart (failover with HA).

## Verify

CPU < 70% for 30 minutes; p99 latency back within SLO.

## Escalate

Page the next tier in [on-call](../oncall.md) if not mitigated within 30 minutes (SEV1) or 2 hours (SEV2). Record
actions in the incident timeline.
