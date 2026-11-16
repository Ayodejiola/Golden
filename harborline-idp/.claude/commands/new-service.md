---
description: Explain how to create a new service on the golden path (prefers Backstage)
argument-hint: <service name> <owner team>
---

The supported way to create a service is the Backstage template **"Python API service"**
(`backstage/templates/python-service/template.yaml`). Do not hand-copy files between repos.

For **$ARGUMENTS**:

1. Confirm the owner team exists in `backstage/catalog/org.yaml` and has a tenant in `gitops/tenants/`.
   If not, point them to the "Tenant onboarding" template first.
2. Walk the user through the template parameters (name, owner, system, tier, data classification, needs PostgreSQL /
   Service Bus) and what each one generates.
3. List the follow-up PRs the template opens (service repo, `gitops/workloads/dev/<team>/<name>/`), and the
   Terraform change needed if they asked for a database or topic (`infra/terraform/stacks/workload-*`).
4. If Backstage is unavailable, render the template skeleton locally with values substituted, into a new directory
   outside this repository, and say so.
