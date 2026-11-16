# Terraform

Infrastructure for the Harborline platform. Thin, opinionated in-house modules composed by deployable stacks
(ADR-0002). Every stack has its own state file and per-environment `env/<env>.tfvars` + `env/<env>.backend.hcl`.

## Stacks and apply order

| # | Stack | Subscription | State container | Applied by |
|---|---|---|---|---|
| 0 | `scripts/bootstrap-state.sh` | management | – | Cloud Admin (once) |
| 1 | `bootstrap` | management | `tfstate-shared` | Cloud Admin (PIM Owner) |
| 2 | `management` | management | `tfstate-shared` | pipeline (`shared` env) |
| 3 | `connectivity` | connectivity | `tfstate-shared` | pipeline (`shared` env) |
| 4 | `platform` | landing zone per env | `tfstate-<env>` | pipeline (`dev` → `stg` → `prod`) |
| 5 | `workload-insurance` | landing zone per env | `tfstate-<env>` | pipeline (`dev` → `stg` → `prod`) |

Stacks find each other's resources **by convention name** (data sources), not remote state, so a stack never
needs read access to another stack's state.

## Modules

| Module | Purpose | Key controls |
|---|---|---|
| `naming` | CAF names + mandatory tags (pure, `terraform test` covered) | approved regions, tag schema |
| `hub-network` | Hub VNet, Firewall Premium (IDPS, TI deny, DNS proxy), Bastion, central Private DNS | egress allow-list |
| `spoke-network` | Spoke VNet, NSGs, UDR to firewall, peering, flow logs | deny-by-default, no default outbound |
| `monitoring` | Log Analytics, Azure Monitor workspace, Managed Grafana, action group | audit retention 2y |
| `container-registry` | ACR Premium, private, zone-redundant, geo-replicated | no admin user, no anonymous pull |
| `key-vault` | Premium, RBAC, purge protection, private | deny public, audit logs |
| `aks` | Private AKS baseline + DCRs + platform alerts | see `docs/security/cis-aks-benchmark.md` |
| `postgresql` | Flexible Server, Entra-only auth, ZR HA, geo backup, pgaudit | no passwords |
| `service-bus` | Premium namespace, topics/subscriptions, DLQ alerts | local auth disabled |
| `workload-identity` | UAMI + federated credentials + scoped roles per service account | no secrets |
| `app-gateway-waf` | WAF_v2, DRS 2.1 + Bot Manager (Prevention), geo + rate limits, e2e TLS | security headers |
| `policy-assignments` | Azure Policy for AKS (PSS restricted, allowed images, private cluster…) | Audit in dev, Deny above |
| `github-oidc` | CI identities federated to GitHub OIDC with ABAC-constrained RBAC delegation | no client secrets |
| `github-runner-network` | GitHub-hosted runners injected into spoke subnets | private data-plane access |
| `private-endpoint` | Private Endpoint + DNS zone group in the hub | central DNS |

## Working locally

```bash
make tf-validate          # fmt, init -backend=false, validate, tflint for all stacks
make tf-test              # terraform test (naming module)
cd stacks/platform
terraform init -backend-config=env/dev.backend.hcl
terraform plan -var-file=env/dev.tfvars      # read-only; apply only via pipeline
```

## Conventions

- Providers: `azurerm >= 4.40, < 5.0`, `azapi >= 2.0`. Lock files are committed (`make lock`).
- Resource names come from `module.naming.names`; tags from `module.naming.tags`. No literals.
- `public_network_access_enabled = false` and Entra-only auth are the defaults. Deviations need an ADR.
- Every PaaS resource ships diagnostic settings to the central workspace with `Dedicated` tables.
- Destructive changes in `prod` need a second approver on the `prod` environment and a change record.
