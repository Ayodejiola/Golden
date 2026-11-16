# PostgreSQL failover or unavailability

| | |
|---|---|
| **Alerts / trigger** | PostgreSQL metric alerts (`cpu`, `memory`, `storage`, `connections_failed`), readiness 503s |
| **Owner** | Owning team + DBA |

Zone-redundant HA fails over automatically in roughly 1–2 minutes; apps reconnect through the pool. Prolonged unavailability, storage pressure or failed connections need action.

## Diagnose (read-only)

```bash
az postgres flexible-server show -g rg-ins-<env>-cac-01 -n psql-ins-<env>-cac-01 \
  --query '{state:state, ha:highAvailability, zone:availabilityZone}'
az monitor activity-log list --resource-id <server-id> --offset 2h -o table
kubectl -n insurance logs deploy/policy-api --since=15m | grep -iE 'psycopg|connection'
```

## Mitigate

1. During automatic failover: wait; readiness probes take pods out of rotation and they recover when connections succeed.
2. Storage > 80%: auto-grow is on — verify; investigate bloat (`pg_stat_user_tables`), archive per retention.
3. Connection failures with a healthy server: check Entra token acquisition (workload identity), private endpoint DNS, NetworkPolicy egress.
4. Forced (planned) failover only with DBA approval: `az postgres flexible-server restart --failover Planned`.
5. Data corruption or accidental delete: point-in-time restore to a new server, validate, switch `DATABASE_HOST` via a GitOps PR.

## Verify

Server `Ready`, HA `Healthy`; readiness 200; no `connections_failed`.

## Escalate

Page the next tier in [on-call](../oncall.md) if not mitigated within 30 minutes (SEV1) or 2 hours (SEV2). Record
actions in the incident timeline.
