# On-call

## Rotations

| Rotation | Scope | Hours | Escalation |
|---|---|---|---|
| Platform primary | AKS, Argo CD, Kyverno, networking, pipelines | 24×7 | Platform secondary → Engineering manager |
| SRE | Observability, SLO breaches across services, DR | 24×7 | Head of SRE |
| Insurance Digital | policy-api, claims-worker, web | 24×7 (tier-1) | Team lead |
| Security on-call | Defender alerts, suspected compromise | 24×7 | CISO |

Alerts route by labels: `team` → owning rotation via the action group webhook. Severity 1 pages; severity 2 pages in
business hours and tickets otherwise; severity 3+ creates tickets.

## Expectations

- Acknowledge pages within 5 minutes (sev 1) / 15 minutes (sev 2).
- Start from the alert's `runbook_url`; use `/incident-assist <alert>` in Claude Code for a read-only checklist.
- Declare an incident for any customer impact or security suspicion (see [incident management](incident-management.md)).
- Hand-off notes at rotation change; review alert noise weekly (target: < 2 non-actionable pages per week).

## Access

On-call engineers have PIM-eligible roles (`grp-sre-oncall`). Elevate with the incident ID as justification; access
expires after 4 hours. Break-glass Entra accounts are stored offline and monitored.
