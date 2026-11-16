# AI-assisted development usage policy

Applies to all engineers using AI coding assistants on Harborline code. Aligned with the NIST AI Risk Management
Framework (Govern, Map, Measure, Manage) and the Harborline data classification standard.

## You may

- Use **Claude Code** (enterprise account) on Harborline repositories, with the repository guardrails active.
- Share code, configuration, architecture docs and synthetic data classified **public**, **internal** or
  **confidential** (without secrets).
- Use the approved MCP servers in `.mcp.json`; propose new ones via a PR reviewed by Security Architecture.
- Let AI draft code, tests, docs, ADRs, threat models and runbook steps — as drafts.

## You must not

- Paste or expose **restricted data** (policyholder PII, claim narratives, health or payment data), production logs,
  secrets, tokens, keys or connection strings.
- Use personal or unapproved AI tools on Harborline code or data.
- Let an agent apply infrastructure, deploy, change policies or access production systems.
- Disable, bypass or edit guardrails (`.claude/`, `.mcp.json`, `CLAUDE.md`) without Security approval.
- Accept generated code you do not understand.

## Accountability

- The human author owns every line merged, regardless of who or what wrote it.
- Mark AI-assisted commits with the trailer `AI-Assisted: claude-code` (tick the PR checkbox).
- Generated code gets the same review, tests and scans as any code; security-sensitive changes (auth, crypto,
  policies, IaC networking/identity) need a second human reviewer.
- Licence hygiene: do not ask for verbatim reproduction of third-party code; dependency review flags licences.

## Measuring value and risk

Tracked quarterly by Platform Product: adoption, PR cycle time, change failure rate of AI-assisted vs other PRs,
guardrail blocks (from audit logs), and incidents attributable to AI-generated changes.

## Reporting

Report suspected data exposure through an AI tool as a security incident (`soc@harborline.example`).
