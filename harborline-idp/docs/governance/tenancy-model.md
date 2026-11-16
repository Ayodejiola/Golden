# Multi-tenancy model

Harborline uses **soft multi-tenancy with strong guardrails**: teams share clusters per environment, isolated by
namespace, identity, network policy, quotas and admission control. Hard isolation (dedicated cluster) is available
by exception for regulatory or noisy-neighbour reasons.

| Layer | Isolation mechanism |
|---|---|
| Identity | Separate Entra groups; namespace-scoped RoleBindings; workload identity per service account |
| GitOps | AppProject per team: one namespace destination, no cluster-scoped kinds, no Role/RoleBinding/Quota edits |
| Admission | Kyverno tenant policies apply to namespaces labelled `harborline.io/tenant: "true"` |
| Network | Default-deny ingress and egress; explicit allows per workload; no NodePort/LoadBalancer |
| Compute | ResourceQuota + LimitRange; PriorityClasses reserved for platform |
| Data | Per-team Azure resources (resource groups, databases, namespaces in Service Bus) with per-identity RBAC |
| Cost | Namespace chargeback (requests × rate) + tagged Azure resources |

## Onboarding

1. Team lead runs the **Tenant onboarding** template in Backstage.
2. Platform Engineering reviews the PR (group, cost centre, classification, quota).
3. On merge, the `tenants` ApplicationSet creates the namespace and AppProject in every cluster within minutes.
4. The team scaffolds services with the **Python API service** template.

## Offboarding

Tenant apps are never auto-pruned. Offboarding is a runbook: archive repos → remove workloads → backup data → remove
tenant folder with `prune` done manually by a platform admin → delete Azure resources via Terraform → remove groups.
