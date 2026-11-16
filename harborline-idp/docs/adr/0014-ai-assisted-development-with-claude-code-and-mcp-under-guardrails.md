# ADR-0014: AI-assisted development with Claude Code and MCP under guardrails

- **Status:** Accepted
- **Date:** 2026-11-16
- **Deciders:** Platform Engineering, Security Architecture, Platform Product
- **Supersedes / Superseded by:** —

## Context

Engineers already use AI assistants. Unmanaged use risks data leakage, unsafe infrastructure changes and prompt
injection via repository or web content.

## Decision

Standardise on **Claude Code** with repository-level guardrails: `CLAUDE.md` policy, `.claude/settings.json`
permissions (deny live mutation and secret reads), **PreToolUse/PostToolUse hooks** that block risky commands, secret/PII
content and control weakening, an audit trail, a curated **MCP server allow-list** (read-only platform catalog, GitHub,
Azure read-only, Terraform registry), sub-agents for security/platform review, and an **advisory AI PR reviewer**.
Humans remain accountable; AI-assisted commits carry a trailer.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Guarded Claude Code + MCP (chosen) | Productivity with enforceable controls; grounded answers via MCP | Hooks are defence in depth, not a sandbox |
| Ban AI tools | Simple policy | Shadow usage without controls |
| Allow any assistant | Flexibility | No consistent controls, audit or data protection |

## Consequences

Security: least privilege for agents, no secrets/PII in prompts, prompt-injection mitigations. Operations: guard tests
in CI. Product: measured via adoption and DORA impact.

## Compliance mapping

NIST CSF GV.RM, GV.SC, PR.AA, PR.DS; NIST AI RMF (Govern, Map, Manage).
