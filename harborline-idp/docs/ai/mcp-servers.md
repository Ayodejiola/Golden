# MCP servers

Model Context Protocol servers give Claude grounded context and tools. Only servers in `.mcp.json` are approved.

| Server | Transport | Access | Purpose | Risk controls |
|---|---|---|---|---|
| `platform-catalog` | stdio (local) | Read-only repository files | Catalog, owners, deployments, runbooks, ADRs, golden-path checks | Path confinement, secret-file refusal, `readOnlyHint` on all tools, no network |
| `github` | HTTP (GitHub-hosted) | User's own token, scoped toolsets | Issues, PRs, Actions runs, code scanning alerts | Merge/delete denied in permissions; PR creation requires confirmation |
| `azure` | stdio (`@azure/mcp`, `--read-only`) | Developer's Azure CLI identity | Query resources, metrics and logs in non-prod | Read-only mode; developers hold Reader only; prod queries done by humans |
| `terraform` | stdio (container, read-only FS) | Public registry docs only | Provider/module documentation lookup | No state, no credentials |

## platform-catalog tools

See `ai/mcp-servers/platform-catalog/README.md`. Example prompts:

- *"Who owns claims-worker and where is it deployed?"* → `get_service`
- *"KubePodCrashLooping fired for policy-api — what do I do?"* → `find_runbook`
- *"Does apps/insurance/claims-worker meet the golden path?"* → `validate_service`

## Adding a server

1. Open a PR adding it to `.mcp.json` with: owner, data it can access, read/write capabilities, auth model.
2. Security Architecture reviews against the [usage policy](usage-policy.md); write-capable servers need an ADR.
3. Add permission rules (`allow`/`ask`/`deny`) for its tools in `.claude/settings.json`.
