# Outbox backlog growing

| | |
|---|---|
| **Alerts / trigger** | `insurance_outbox_pending` rising (business KPI dashboard) |
| **Owner** | Owning team |

Events are committed to the outbox but not published: Service Bus unreachable, identity/RBAC problem, or relay unhealthy. Customer requests still succeed; downstream processing is delayed.

## Diagnose (read-only)

```bash
kubectl -n insurance logs deploy/policy-api --since=15m | grep -i outbox
kubectl -n insurance get pods -l app.kubernetes.io/name=policy-api
kubectl -n insurance port-forward deploy/policy-api 8080:8080 &  # then: curl localhost:8080/healthz/ready
```

## Mitigate

1. Check Service Bus health and private endpoint DNS from the namespace (NetworkPolicy allows 5671/443 to `snet-pe`).
2. Check the `Azure Service Bus Data Sender` role for `id-ins-policy-api-<env>` on the topic.
3. The relay retries automatically; rows with `attempts >= 20` stop retrying — after fixing the cause a DBA resets them: `UPDATE outbox SET attempts = 0 WHERE published_at IS NULL;`.
4. Duplicates are safe (deterministic message IDs + idempotent consumers).

## Verify

`insurance_outbox_pending` returns to ~0; readiness shows `outbox: ok`.

## Escalate

Page the next tier in [on-call](../oncall.md) if not mitigated within 30 minutes (SEV1) or 2 hours (SEV2). Record
actions in the incident timeline.
