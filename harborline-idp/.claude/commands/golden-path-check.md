---
description: Check a service against the golden path and produce a scorecard with fixes
argument-hint: <path to service>
---

Evaluate **$ARGUMENTS** against `docs/governance/golden-path.md` and `docs/governance/scorecards.md`.

1. Call the `platform-catalog` MCP tool `validate_service` with the service path and summarise its findings.
2. Manually confirm: Dockerfile is multi-stage, non-root, pinned base; health endpoints exist; OTel is initialised;
   logs are JSON without PII; GitOps values use `image.digest`; `catalog-info.yaml` has owner, system, lifecycle,
   tier and `backstage.io/techdocs-ref`.
3. Output a table: requirement · status (pass/fail/n.a.) · evidence path · fix.
4. Offer concrete diffs for failures, but do not apply changes to `gitops/workloads/prod/**`.
