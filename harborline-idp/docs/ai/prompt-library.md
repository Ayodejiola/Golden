# Prompt library

Prompts that work well with the repository guardrails and MCP servers. Slash commands live in `.claude/commands/`.

## Slash commands

| Command | Use |
|---|---|
| `/new-adr <title>` | Draft an ADR with alternatives, WAF consequences and compliance mapping |
| `/threat-model <service>` | STRIDE threat model with a Mermaid DFD, mapped to NIST CSF / ASVS |
| `/golden-path-check <path>` | Golden-path scorecard with concrete fixes |
| `/new-service <name> <team>` | Walkthrough of the Backstage template and follow-up PRs |
| `/incident-assist <alert>` | Read-only incident co-pilot: runbook, diagnostics, comms drafts |

## Sub-agents

- `security-reviewer` — reviews the current diff against CIS AKS, ASVS, NIST CSF; proactive before PRs.
- `platform-reviewer` — reliability, operability, cost and consistency review.

## Good prompts

1. *Add an endpoint `GET /api/v1/claims` to policy-api that lists the caller's claims with pagination. Follow the
   existing ownership pattern in repository.py, add unit tests and update openapi.yaml. Do not touch migrations.*
2. *Explain why `restrict-image-registries` denied my pod and show the minimal values.yaml change.*
3. *Write a Kyverno test case proving tenant Roles cannot use wildcard verbs, and run `make policy-test`.*
4. *Using `find_runbook`, prepare a checklist for `PolicyApiLatencyFastBurn` in stg and the KQL I should run.*

## Anti-patterns

- "Fix prod" — agents cannot and must not change production; ask for a PR or a diagnosis instead.
- Pasting logs or database rows from production — use synthetic reproductions.
- "Disable the policy so it deploys" — request an exception and fix the cause.
