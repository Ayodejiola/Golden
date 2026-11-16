# Contributing to the Harborline IDP

The platform is a product; this repository is its source. Contributions from tenant teams are welcome.

## Ground rules

1. **Everything through a pull request.** `main` is protected: 2 approvals (1 code owner), signed commits, linear history,
   all required checks green. Nobody — including platform admins — applies changes outside pipelines except under the
   break-glass procedure in `docs/operations/incident-management.md`.
2. **Conventional Commits** (`feat:`, `fix:`, `docs:`, `chore:`, `sec:`, `refactor:`). Breaking changes to the platform
   contract use `feat!:` and need a migration note in `CHANGELOG.md`.
3. **Docs travel with code.** New alert → runbook. New architectural decision → ADR. New resource type → standards
   update. Reviewers block PRs that change behaviour without docs.
4. **AI-assisted work** follows `docs/ai/usage-policy.md`: human ownership, `AI-Assisted:` commit trailer, no customer data.

## Local setup

```bash
pipx install pre-commit && pre-commit install
make validate
```

Tooling versions are pinned in `.github/workflows/*` and `.tool-versions`.

## What reviewers look for

| Area | Must have |
|---|---|
| Terraform | `naming` module tags, private networking, Entra auth, diagnostic settings, `tflint` + `checkov` clean |
| Kubernetes | Golden-service chart only, digest-pinned images, policy tests updated if policies change |
| Pipelines | Actions pinned to SHA, least-privilege `permissions:`, OIDC (no stored cloud credentials) |
| Apps | Tests, OTel spans for new I/O, no PII in logs, input validation, authZ on every endpoint |

## Changing a platform policy

Policies in `platform/policies/` and Azure Policy assignments are owned by Security Architecture. Open a PR with tests
that prove the new behaviour and link the risk acceptance or exception record. See
`docs/governance/exceptions-process.md`.
