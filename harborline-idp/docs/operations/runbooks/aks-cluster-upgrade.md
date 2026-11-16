# AKS minor version upgrade

| | |
|---|---|
| **Alerts / trigger** | Planned change (no alert) |
| **Owner** | Platform primary |

Minor version upgrades are promoted dev → stg → prod via `kubernetes_version` in `infra/terraform/stacks/platform/env/<env>.tfvars`. Patch and node image updates are automatic inside the maintenance window.

## Diagnose (read-only)

```bash
az aks get-upgrades -g rg-plat-<env>-cac-01 -n aks-plat-<env>-cac-01 -o table
kubectl get --raw /metrics | grep apiserver_requested_deprecated_apis
kubectl get pdb -A
```

## Mitigate

1. Read the AKS release notes and Kubernetes deprecations for the target minor.
2. Check deprecated API usage and add-on compatibility (Kyverno, Argo CD, OTel Collector; KEDA is managed).
3. Open a PR bumping `kubernetes_version` for dev; merge; watch the upgrade (`az aks show --query provisioningState`).
4. Soak one week in dev, then repeat for stg and prod (prod: normal change, business hours, not Friday).
5. If a drain stalls: identify the PDB with zero allowed disruptions, scale the workload or use a time-boxed exception; never delete PDBs silently.

## Verify

`az aks show --query kubernetesVersion` matches the target; all Argo CD apps Healthy; SLO dashboards green.

## Escalate

Page the next tier in [on-call](../oncall.md) if not mitigated within 30 minutes (SEV1) or 2 hours (SEV2). Record
actions in the incident timeline.
