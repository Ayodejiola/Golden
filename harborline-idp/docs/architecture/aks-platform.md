# AKS platform design

Each environment runs one private AKS cluster built by `infra/terraform/modules/aks` (AKS baseline reference
architecture, CIS AKS Benchmark).

## Cluster configuration

| Area | Setting | Rationale |
|---|---|---|
| Tier | Free (dev), Standard (stg/prod) | Uptime SLA and cost analysis where it matters |
| API server | Private cluster, custom private DNS zone in hub, no public FQDN | CIS 5.4.2; no internet attack surface |
| AuthN/Z | Entra ID + Azure RBAC, local accounts disabled | CIS 5.5.x; central access reviews |
| Network | Azure CNI Overlay, Cilium dataplane + network policy, UDR egress | ADR-0006: eBPF performance, address efficiency |
| Identity | OIDC issuer + workload identity, user-assigned control-plane and kubelet identities | ADR-0005 |
| Nodes | AzureLinux, ephemeral OS disks, encryption at host, 3 zones | Smaller attack surface, fast reimage |
| Pools | `system` (CriticalAddonsOnly) + `apps` (user) with autoscaler | Isolate add-ons from tenant load |
| Upgrades | `patch` auto-upgrade channel, `NodeImage` OS channel, Sunday 02:00 AT windows, max surge 33% | Continuous patching inside maintenance windows |
| Add-ons | Azure Policy, Defender, Key Vault CSI (rotation 2 m), KEDA, VPA, app routing (managed NGINX, no default public controller), image cleaner | Managed lifecycle |
| Monitoring | Container Insights (DCR, ContainerLogV2), managed Prometheus (DCR/DCE), control-plane logs (kube-audit-admin, guard, …) | See [observability](observability.md) |

## In-cluster platform services (GitOps)

| Namespace | Component | Delivered by |
|---|---|---|
| `argocd` | Argo CD (HA in prod, Entra SSO, WI for ACR) | `addons-helm` |
| `kyverno` | Kyverno + Harborline policies | `addons-helm`, `addons-manifests` |
| `observability` | OpenTelemetry Collector | `addons-helm` |
| `app-routing-system` | Managed NGINX (internal controller `nginx-internal`) | AKS add-on + `platform-config` |
| `kube-system` | KEDA, VPA, CSI drivers, ama-metrics, Cilium | AKS-managed |
| `backstage` (prod) | Developer portal | `addons-helm` |
| `<team>` | Tenant workloads | `tenants` + `workloads` ApplicationSets |

## Capacity and scaling

- Pod-level: HPA on CPU/memory (APIs) or KEDA on Service Bus backlog (workers), bounded per service.
- Node-level: cluster autoscaler per pool; quotas per tenant namespace protect shared capacity.
- `max_pods = 110` per node; system pool sized for add-ons at 3 nodes minimum in stg/prod.

## Upgrade strategy

1. AKS minor version bumps start in dev (`env/dev.tfvars`), soak one week, then stg, then prod — the same PR
   pattern as application promotion. Runbook: [cluster upgrade](../operations/runbooks/aks-cluster-upgrade.md).
2. Patch versions and node images are applied automatically inside the maintenance windows.
3. PDBs (golden chart default `maxUnavailable: 1`) and surge settings keep workloads available during drains.

## Known limitations

- **KMS etcd encryption with CMK** requires API Server VNet Integration; until it is enabled, etcd uses
  platform-managed keys (risk RA-0003, roadmap R2). The module already supports `kms`.
- One cluster per environment: a cluster-level failure in prod falls back to the DR procedure (rebuild in
  Canada East from Git) rather than active-active (see [disaster recovery](../operations/disaster-recovery.md)).
