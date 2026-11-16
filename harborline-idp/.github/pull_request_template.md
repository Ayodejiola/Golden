## What and why

<!-- One paragraph. Link the issue / ADR. -->

## Type

- [ ] Feature  - [ ] Fix  - [ ] Security  - [ ] Docs  - [ ] Platform contract change (needs CHANGELOG + migration note)

## Checklist

- [ ] Tests added/updated and `make validate` passes locally
- [ ] Docs updated (runbook for new alerts, ADR for decisions, standards for new resource types)
- [ ] No secrets, no customer data, no public endpoints introduced
- [ ] Security controls unchanged **or** exception linked: <!-- EXC-#### -->
- [ ] Terraform plan reviewed (bot comment) — no unexpected destroys
- [ ] For `gitops/workloads/prod/**`: digest promoted from stg, change window respected

## AI assistance

- [ ] This PR includes AI-assisted changes (commits carry `AI-Assisted:` trailer) and I have reviewed every line.

## Rollback plan

<!-- Revert PR? Feature flag? Data migration reversible? -->
