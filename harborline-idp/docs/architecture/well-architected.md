# Microsoft Well-Architected Framework assessment

Scores are the platform team's self-assessment (1 = initial, 5 = optimised) reviewed quarterly with Cloud
Architecture. Each row links the design choice to where it lives.

## Reliability — 4/5

| Practice | Implementation |
|---|---|
| Zone redundancy | AKS pools across 3 zones, ZR PostgreSQL HA, Service Bus Premium, ZR ACR, zonal App Gateway |
| Health modelling | Liveness vs readiness split; readiness reflects dependencies; startup probes |
| Graceful degradation | Outbox decouples API from Service Bus outages; KEDA buffers worker load |
| Safe deployment | Rolling update `maxUnavailable: 0`, PDBs, PreSync migrations, progressive envs, sync windows |
| Recovery | Geo-redundant backups, Git-rebuildable clusters, DR runbook with RTO 4 h / RPO 15 min for tier-1 |
| Gap | Single-region active runtime; DR is rebuild-based (roadmap: warm standby for tier-0) |

## Security — 4/5

| Practice | Implementation |
|---|---|
| Identity first | Entra everywhere, workload identity, OIDC CI, PIM, ABAC-constrained delegation |
| Network segmentation | Hub-spoke, forced tunnelling, private endpoints, default-deny NetworkPolicy, WAF |
| Supply chain | Signed images, SLSA provenance, SBOMs, admission verification, mirrored dependencies |
| Policy as code | Azure Policy (Deny in stg/prod), Kyverno, Conftest, Checkov |
| Threat detection | Defender for Containers, Firewall IDPS/TI, audit logs to SIEM |
| Gap | CMK for etcd (KMS) and AMPLS pending (RA-0003, RA-0004) |

## Cost optimisation — 3/5

| Practice | Implementation |
|---|---|
| Right-sizing per env | Free AKS tier + burstable PG in dev; autoscaling everywhere |
| Visibility | Mandatory cost-centre tags, AKS cost analysis, namespace chargeback dashboard |
| Elasticity | Cluster autoscaler, HPA, KEDA scale-to-min for workers |
| Gap | Reserved instances / savings plans for prod baseline not yet purchased; dev clusters not stopped nights (roadmap) |

## Operational excellence — 4/5

| Practice | Implementation |
|---|---|
| Everything as code | Terraform, GitOps, policies, dashboards, alerts, SLOs, docs |
| Observability | OTel standard, golden-signal dashboards, SLO burn-rate alerting, runbook links on every alert |
| Safe change | PR-based, plan comments, drift detection, environment gates |
| Learning | Blameless post-incident reviews, ADRs, scorecards |

## Performance efficiency — 4/5

| Practice | Implementation |
|---|---|
| Efficient networking | Cilium eBPF dataplane, overlay addressing |
| Scaling signals | Event-driven scaling on queue depth, CPU/memory HPA |
| Data | Connection pooling with token-auth reconnects, indexed access paths, statement timeouts |
| Gap | No load-test gate in pipeline yet (roadmap R2: k6 in stg) |
