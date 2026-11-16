# AKS node NotReady / node saturation

| | |
|---|---|
| **Alerts / trigger** | `KubeNodeNotReady`, `NodeCPUSaturation`, `PersistentVolumeFillingUp` |
| **Owner** | Platform primary |

One or more nodes stopped reporting Ready, or a node is saturated. Pods on the node are evicted after the toleration window; zone spreading and PDBs should keep services available.

## Diagnose (read-only)

```bash
kubectl get nodes -o wide
kubectl describe node <node> | sed -n '/Conditions/,/Addresses/p'
kubectl get pods -A --field-selector spec.nodeName=<node>
az aks nodepool list -g rg-plat-<env>-cac-01 --cluster-name aks-plat-<env>-cac-01 -o table
# Container Insights (KQL)
# KubeNodeInventory | where TimeGenerated > ago(1h) | summarize arg_max(TimeGenerated, Status) by Computer
```

## Mitigate

1. If a single node: cordon and let AKS auto-repair act (node auto-repair restarts/reimages unhealthy nodes).
2. If many nodes in one zone: check Azure status for the zone; workloads should already be rescheduled — verify PDB-blocked drains.
3. If saturation: check top consumers (`kubectl top pods -A --sort-by=cpu`), confirm requests are realistic, raise pool `max_count` via PR if the autoscaler is capped.
4. If disk/PVC full: expand the PVC (StorageClass allows expansion) or clean up; check image cleaner is running.

## Verify

Node Ready for 10 minutes; no Pending pods; alert auto-resolved.

## Escalate

Page the next tier in [on-call](../oncall.md) if not mitigated within 30 minutes (SEV1) or 2 hours (SEV2). Record
actions in the incident timeline.
