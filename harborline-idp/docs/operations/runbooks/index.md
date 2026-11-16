# Runbooks

Every alert links here through its `runbook_url`. Runbooks use **read-only diagnostics first**; changes go
through Git unless the [break-glass](../incident-management.md#break-glass) procedure is invoked.

| Runbook | Alerts / trigger | Owner |
|---|---|---|
| [AKS node NotReady / node saturation](aks-node-not-ready.md) | `KubeNodeNotReady`, `NodeCPUSaturation`, `PersistentVolumeFillingUp` | Platform primary |
| [AKS minor version upgrade](aks-cluster-upgrade.md) | Planned change (no alert) | Platform primary |
| [Argo CD application out of sync or degraded](argocd-sync-failure.md) | `ArgoCDAppOutOfSync` | Platform primary (platform apps) / owning team (workloads) |
| [PostgreSQL failover or unavailability](postgres-failover.md) | PostgreSQL metric alerts (`cpu`, `memory`, `storage`, `connections_failed`), readiness 503s | Owning team + DBA |
| [PostgreSQL CPU / connection saturation](postgres-connection-saturation.md) | `alert-psql-*-cpu`, `alert-psql-*-memory` | Owning team |
| [Service Bus dead-letter messages](servicebus-dead-letter.md) | `alert-sbns-*-deadletters`, `alert-sbns-*-throttled` | Owning team (claims-worker) |
| [Outbox backlog growing](outbox-backlog.md) | `insurance_outbox_pending` rising (business KPI dashboard) | Owning team |
| [High error rate / availability burn](high-error-rate.md) | `PolicyApiAvailabilityFastBurn`, `PolicyApiAvailabilitySlowBurn`, `KubePodCrashLooping`, `KubeDeploymentReplicasMismatch`, `KubeContainerOOMKilled` | Owning team |
| [High latency (latency SLO burn)](high-latency.md) | `PolicyApiLatencyFastBurn` | Owning team |
| [Image or pod denied by admission policy](image-admission-denied.md) | `KyvernoAdmissionFailuresHigh`, Argo CD sync errors mentioning Kyverno or Gatekeeper | Owning team; Platform for policy bugs |
| [Outbound call blocked by the hub firewall](egress-blocked-by-firewall.md) | Application errors (timeouts, TLS failures) to external endpoints; firewall deny logs | Owning team + Network Engineering |
| [TLS certificate expiry](certificate-expiry.md) | Key Vault `CertificateNearExpiry` event / WAF backend health warnings | Platform primary |
| [Secret and credential rotation](secret-and-credential-rotation.md) | Scheduled (90 days) / suspected compromise | Secret owner (see inventory) |
| [Security incident response (platform)](security-incident-response.md) | Defender for Containers/Cloud high-severity alert, firewall IDPS hit, suspicious Kyverno denials, leaked credential report | Security on-call (IC) + Platform primary |
