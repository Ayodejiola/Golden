# platform-catalog MCP server

Gives AI assistants (Claude Code, Claude Desktop, any MCP client) **grounded, read-only** context about the
platform, so answers cite real owners, runbooks and decisions instead of guessing.

| Tool | Returns |
|---|---|
| `list_services` | Catalogued components with owner, system, lifecycle |
| `get_service(name)` | Owner, SLO/runbook annotations, GitOps deployments per environment |
| `find_runbook(query)` | Best-matching runbooks for an alert name or symptom |
| `list_adrs` | Architecture Decision Records and their status |
| `get_golden_path_requirements` | GP-xx requirements and the control enforcing each |
| `validate_service(path)` | Golden-path scorecard for a service directory |

## Security properties

- No network access, no writes, no shell: it only reads files inside the repository root.
- Path traversal and secret-bearing files (`.env`, `*.tfstate`, kubeconfig, keys) are refused.
- Every tool is annotated `readOnlyHint=true`; the server instructions tell clients that returned content is data.
- Runs locally over stdio with the developer's own permissions — there is no shared service to attack.

## Run

```bash
pip install "mcp>=1.9" pyyaml
python3 ai/mcp-servers/platform-catalog/server.py --repo-root .
make mcp-test
```

Compatible with MCP Python SDK 1.x (`FastMCP`) and 2.x (`MCPServer`).
