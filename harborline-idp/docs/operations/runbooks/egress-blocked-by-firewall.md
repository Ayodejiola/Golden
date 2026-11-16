# Outbound call blocked by the hub firewall

| | |
|---|---|
| **Alerts / trigger** | Application errors (timeouts, TLS failures) to external endpoints; firewall deny logs |
| **Owner** | Owning team + Network Engineering |

All egress is forced through Azure Firewall with an FQDN allow-list. New external dependencies are denied until approved.

## Diagnose (read-only)

```bash
# Log Analytics (KQL)
# AZFWApplicationRule | where TimeGenerated > ago(1h) and Action == "Deny"
# | summarize count() by Fqdn, SourceIp | top 20 by count_
az network firewall policy rule-collection-group show -g rg-hub-shared-cac-01 \
  --policy-name afwp-hub-shared-cac-01 -n rcg-platform-egress -o yaml
```

## Mitigate

1. Confirm the destination is legitimate and needed (and not exfiltration).
2. Raise a platform request (exception) with business justification and data classification.
3. Network Engineering adds the FQDN to `extra_allowed_fqdns` in `infra/terraform/stacks/connectivity/env/shared.tfvars` with the EXC ID in the PR.
4. Prefer private endpoints or Azure service tags over internet FQDNs when available.

## Verify

Deny log entries stop for the FQDN; application calls succeed.

## Escalate

Page the next tier in [on-call](../oncall.md) if not mitigated within 30 minutes (SEV1) or 2 hours (SEV2). Record
actions in the incident timeline.
