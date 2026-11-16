# Service Bus dead-letter messages

| | |
|---|---|
| **Alerts / trigger** | `alert-sbns-*-deadletters`, `alert-sbns-*-throttled` |
| **Owner** | Owning team (claims-worker) |

Service Bus moves messages to the dead-letter queue when they are poison (invalid schema, missing claim) or exceed the max delivery count. Dead-lettered messages mean a claim was not triaged automatically.

## Diagnose (read-only)

```bash
az servicebus topic subscription show -g rg-ins-<env>-cac-01 --namespace-name sbns-ins-<env>-cac-01 \
  --topic-name claims -n triage --query countDetails
kubectl -n insurance logs deploy/claims-worker --since=1h | grep -E 'dead-lettering|poison'
```

## Mitigate

1. Peek (do not receive) dead-letter messages with Service Bus Explorer in the portal under PIM; read `DeadLetterReason` and `DeadLetterErrorDescription`.
2. **Schema/type errors:** a producer shipped an incompatible event — roll back the producer; make the consumer tolerant if appropriate.
3. **Claim not found:** check outbox ordering; resubmit once the claim exists.
4. Resubmit fixed messages with Service Bus Explorer *Resubmit* (the idempotent inbox prevents double processing).
5. Throttling: scale messaging units via Terraform (`service_bus_capacity`).

## Verify

Dead-letter count back to 0 (or explained and tracked); triage outcomes flowing in the business dashboard.

## Escalate

Page the next tier in [on-call](../oncall.md) if not mitigated within 30 minutes (SEV1) or 2 hours (SEV2). Record
actions in the incident timeline.
