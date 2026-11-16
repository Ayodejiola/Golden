# Incident management

## Severity

| Sev | Definition | Examples | Response |
|---|---|---|---|
| SEV1 | Major customer impact or data breach suspected | Portal down, error budget burning 14×, confirmed intrusion | IC + comms lead, exec notification, status page in 15 min |
| SEV2 | Partial impact or high risk | Claims triage delayed > 30 min, one zone degraded | IC, status page if customer-visible |
| SEV3 | Minor/internal | Dev cluster outage, pipeline broken | Owning team |

## Roles

- **Incident commander (IC):** coordinates, decides, keeps the timeline. Not the person typing commands.
- **Operations lead:** investigates and mitigates using runbooks.
- **Comms lead:** status page, stakeholders, regulator liaison with Legal/Privacy for data incidents.
- **Scribe:** timeline in the incident channel.

## Flow

1. Declare in Teams `#inc-<date>-<slug>`; set severity; page roles.
2. Stabilise first (rollback, scale, fail over) — root cause later.
3. Communicate every 30 minutes (SEV1) / 60 minutes (SEV2).
4. Resolve when SLIs are back within SLO for 30 minutes.
5. Post-incident review within 5 business days (blameless), actions tracked as issues with owners and dates.

## Communication templates

**Status page (initial):**
> We are investigating an issue affecting *<capability>* for some customers since *<time AT>*. Next update by *<time>*.

**Internal update:**
> SEV*n* · *<summary>* · Impact: *<who/what>* · Current action: *<mitigation>* · Next update: *<time>* · IC: *<name>*

## Break-glass

If Argo CD or the pipeline is unavailable and a fix is urgent: IC approves; on-call elevates via PIM; change applied
with `kubectl`/`az` from Bastion; the same change is committed to Git within 24 hours (Argo CD would otherwise revert
it); the action is logged in the incident timeline. Security incidents follow
[security incident response](runbooks/security-incident-response.md) and privacy breach notification obligations
(PIPEDA / provincial) via Legal.
