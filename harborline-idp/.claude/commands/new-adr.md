---
description: Draft a new Architecture Decision Record from the Harborline template
argument-hint: <short decision title>
---

Draft an ADR for: **$ARGUMENTS**

1. Read `docs/adr/0000-template.md` and list existing ADRs in `docs/adr/` to pick the next number and avoid
   contradicting an accepted decision (if it supersedes one, say so and update the old ADR's status line).
2. Use the `platform-catalog` MCP server (`get_golden_path_requirements`) to check which standards apply.
3. Write `docs/adr/NNNN-kebab-title.md` with status `Proposed`, at least two real alternatives with trade-offs,
   consequences across all five Well-Architected pillars, and the security/compliance impact (NIST CSF category).
4. Add the ADR to `docs/adr/index.md` and `mkdocs.yml` nav.
5. Do not invent benchmark numbers or prices; mark anything that needs verification with `TODO(verify):`.
