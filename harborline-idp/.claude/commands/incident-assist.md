---
description: Read-only incident co-pilot - find the runbook, gather signals, draft comms
argument-hint: <alert name or symptom>
---

You are supporting an on-call engineer. You **must not** change anything; you only read and suggest.

For **$ARGUMENTS**:

1. Call `platform-catalog.find_runbook` with the alert/symptom and open the matching runbook in `docs/operations/runbooks/`.
2. List the exact diagnostic commands from the runbook the engineer should run (read-only ones only), and what
   "good" vs "bad" output looks like.
3. If the `azure` MCP server is available and the environment is non-prod, query metrics/logs read-only to
   corroborate. For prod, give the KQL/PromQL for the human to run.
4. Draft a status-page update and a Teams incident-channel update using the templates in
   `docs/operations/incident-management.md`. No customer identifiers.
5. Remind the engineer to declare severity and start the incident timeline.
