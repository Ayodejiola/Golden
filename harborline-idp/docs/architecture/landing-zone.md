# Azure Landing Zone alignment

Harborline follows the Cloud Adoption Framework **Azure Landing Zone (ALZ)** conceptual architecture. The ALZ
platform (management groups, core policy, identity subscription) is deployed by the enterprise ALZ accelerator
(Azure Verified Modules); **this repository owns the application landing zones** for the IDP and the shared
platform services it needs (ADR-0002).

## Management group hierarchy

| Management group | Purpose | Key policy assignments (ALZ + Harborline) |
|---|---|---|
| `hbl` (intermediate root) | Tenant-wide guardrails | Microsoft Cloud Security Benchmark, allowed locations (`canadacentral`, `canadaeast`), deny classic resources |
| `hbl-platform-management` | Logging, monitoring, CI identities, ACR | Diagnostic settings DINE, Defender for Cloud plans |
| `hbl-platform-connectivity` | Hub networking, DNS | Deny public IPs except approved (firewall, bastion, WAF), NSG on subnets |
| `hbl-landingzones-corp` | IDP landing zones (dev/stg/prod) | **Deny public endpoints**, private DNS integration, AKS policies (this repo: `modules/policy-assignments`) |
| `hbl-sandbox` | Experiments, no connectivity | Budget caps, auto-expiry |

## Subscriptions

| Subscription | Stack(s) | Notes |
|---|---|---|
| `sub-hbl-management` | `bootstrap`, `management` | Terraform state, CI identities, Log Analytics, Azure Monitor workspace, Managed Grafana, shared ACR |
| `sub-hbl-connectivity` | `connectivity` | Hub VNet, Azure Firewall Premium, Bastion, central Private DNS zones |
| `sub-hbl-lz-dev` / `-stg` / `-prod` | `platform`, `workload-*` | One spoke + AKS per environment; workloads share the spoke but get their own resource groups and state |

One subscription per environment keeps blast radius, quotas, cost reporting and RBAC boundaries clean; promotion
between environments never shares credentials.

## Design area mapping

| ALZ design area | Implementation |
|---|---|
| Billing & tenant | Cost-centre tag mandatory (`naming` module + Azure Policy) |
| Identity & access | Entra groups, PIM for admin roles, workload identity, GitHub OIDC (see [identity](identity-and-access.md)) |
| Resource organisation | CAF naming (`<type>-<workload>-<env>-<region>-<nn>`), mandatory tags |
| Network topology | Hub-spoke, forced tunnelling, Private Link, central DNS (see [network](network.md)) |
| Security | Defender for Containers, Azure Policy, Kyverno, WAF, Key Vault Premium, private endpoints |
| Management | Central Log Analytics, AMW, Grafana, action groups, drift detection |
| Governance | Policy as code, exceptions register, scorecards, CODEOWNERS |
| Platform automation & DevOps | Terraform stacks, GitHub Actions with environments, Argo CD |

## Region strategy

Primary **Canada Central**, DR **Canada East** (data residency: all restricted data stays in Canada). ACR is
geo-replicated, PostgreSQL backups are geo-redundant, Service Bus geo-disaster recovery pairing is documented in
[disaster recovery](../operations/disaster-recovery.md).
