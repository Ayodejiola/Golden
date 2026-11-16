# Security incident response (platform)

| | |
|---|---|
| **Alerts / trigger** | Defender for Containers/Cloud high-severity alert, firewall IDPS hit, suspicious Kyverno denials, leaked credential report |
| **Owner** | Security on-call (IC) + Platform primary |

Suspected compromise of a workload, identity or pipeline. Preserve evidence, contain, eradicate, recover — and involve Legal/Privacy early if restricted data may be affected.

## Diagnose (read-only)

```bash
# Log Analytics (KQL)
# AzureActivity | where TimeGenerated > ago(24h) and Caller == "<identity>" | project TimeGenerated, OperationNameValue, ResourceId
# AKSAuditAdmin | where TimeGenerated > ago(24h) and User contains "<identity>" | project TimeGenerated, Verb, ObjectRef
# SecurityAlert | where TimeGenerated > ago(24h) | project TimeGenerated, AlertName, CompromisedEntity, Severity
az role assignment list --assignee <principal-id> --all -o table
```

## Mitigate

1. **Declare** SEV1/SEV2 with Security as IC; start the timeline; keep details out of public channels.
2. **Preserve:** snapshot affected node disks (`az snapshot create`), export pod logs, keep the pod running but isolated where possible.
3. **Contain:** apply a deny-all NetworkPolicy to the pod/namespace; remove federated credentials or role assignments of the affected identity; revoke GitHub tokens/App keys; disable compromised Entra accounts.
4. **Eradicate:** rebuild from Git (cordon/drain/delete nodes, redeploy signed images) and rotate every secret the workload could reach.
5. **Recover:** restore service and monitor closely for 72 hours.
6. **Notify:** Legal/Privacy decide on regulator and individual notification (PIPEDA breach of security safeguards) when restricted data is involved.
7. **Learn:** blameless review; update threat models and controls.

## Verify

Containment confirmed, no further indicators for 72 hours, credentials rotated, report filed.

## Escalate

Page the next tier in [on-call](../oncall.md) if not mitigated within 30 minutes (SEV1) or 2 hours (SEV2). Record
actions in the incident timeline.
