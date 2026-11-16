# CIS Azure Kubernetes Service Benchmark mapping

Maps CIS AKS Benchmark recommendations to their enforcement point. Section numbers follow the CIS AKS Benchmark
structure (v1.x); verify numbering against the release your auditors use. Worker-node file-permission checks
(section 3) are AKS-managed on AzureLinux node images and validated by Defender for Containers.

| CIS | Recommendation | Status | Enforcement point |
|---|---|---|---|
| 2.1.1 | Enable audit logs | ✅ | AKS diagnostic settings `kube-audit-admin`, `guard` → Log Analytics (`modules/aks/main.tf`) |
| 3.x | Worker node configuration (kubelet, file permissions) | ✅ (managed) | AKS-managed AzureLinux images, `NodeImage` upgrade channel, Defender recommendations |
| 4.1.1 | cluster-admin only where required | ✅ | Azure RBAC Cluster Admin only for `grp-platform-admins` via PIM; Kyverno `rbac-hygiene` blocks tenant bindings |
| 4.1.2 | Minimise access to secrets | ✅ | No workload secrets in etcd by default; tenants get `view` (no secrets); CSI mounts files |
| 4.1.3 | Minimise wildcards in Roles | ✅ | Kyverno `rbac-hygiene/no-wildcards-in-tenant-roles`; tenants cannot create Roles (AppProject) |
| 4.1.4 | Minimise access to create pods | ✅ | Humans have read-only access; workloads created only by Argo CD |
| 4.1.5 | Default service accounts not used | ✅ | Golden chart creates a dedicated SA per workload |
| 4.1.6 | SA tokens only mounted where necessary | ✅ | `automountServiceAccountToken: false` (chart + Kyverno `tenant-boundaries/no-automount-token`) |
| 4.2.1–4.2.9 | Pod Security (privileged, hostPID/IPC/Network, privilege escalation, root, capabilities…) | ✅ | Kyverno `pod-security-restricted` + Azure Policy PSS restricted initiative (Deny in stg/prod) + namespace PSA labels |
| 4.3.1 | CNI supports network policies | ✅ | Cilium network policy (ADR-0006) |
| 4.3.2 | All namespaces have network policies | ✅ | Tenant `default-deny` (GitOps) + Kyverno `generate-tenant-defaults` backstop |
| 4.4.1 | Prefer secrets as files over env | ✅ | Chart mounts CSI secrets at `/mnt/secrets`; env sync only for Backstage (documented) |
| 4.4.2 | External secret storage | ✅ | Key Vault Premium + Secrets Store CSI driver with rotation |
| 4.5.1 | Configure image provenance (admission) | ✅ | Kyverno `verify-image-signatures` (Sigstore + SLSA) |
| 4.6.1 | Administrative boundaries with namespaces | ✅ | Namespace per tenant, AppProjects, quotas |
| 4.6.2 | seccomp RuntimeDefault | ✅ | Chart pod security context; PSS restricted |
| 4.6.3 | Apply security context | ✅ | Chart: non-root, read-only rootfs, drop ALL |
| 4.6.4 | Default namespace not used | ✅ | Kyverno `tenant-boundaries/no-default-namespace` |
| 5.1.1 | Image vulnerability scanning | ✅ | Trivy in CI (fail on fixable HIGH/CRITICAL), Defender for Containers registry + runtime scanning |
| 5.1.2 | Minimise user access to ACR | ✅ | No admin user; AcrPush only for CI identity; humans read-only |
| 5.1.3 | Cluster has read-only ACR access | ✅ | Kubelet identity `AcrPull` only |
| 5.1.4 | Only approved registries | ✅ | Kyverno `restrict-image-registries` + Azure Policy allowed images + firewall (no public registries) |
| 5.2.1 | Dedicated identities for workloads | ✅ | Workload identity per service account (ADR-0005) |
| 5.3.1 | Encrypt secrets in etcd with KMS (CMK) | ⚠️ Partial | Platform-managed encryption today; module supports `kms`; requires API Server VNet Integration — RA-0003, roadmap R2 |
| 5.4.1 | Restrict control-plane endpoint access | ✅ | Private cluster, no public FQDN |
| 5.4.2 | Private endpoint, public access disabled | ✅ | `private_cluster_enabled = true`, Azure Policy "private clusters" Deny |
| 5.4.3 | Private nodes | ✅ | Nodes in private subnets, UDR egress, `default_outbound_access_enabled = false` |
| 5.4.4 | Network policy enabled | ✅ | Cilium |
| 5.4.5 | TLS for load balancer traffic | ✅ | WAF TLS 1.2+ policy, re-encryption to internal NGINX with Key Vault certificates |
| 5.5.1 | Entra ID for user authentication | ✅ | Entra integration with Azure RBAC; `local_account_disabled = true` |
| 5.5.2 | Kubernetes RBAC | ✅ | Azure RBAC + namespaced Kubernetes RoleBindings for tenants |

**Continuous evidence:** Azure Policy compliance (Defender for Cloud regulatory compliance dashboard), Kyverno
PolicyReports, `k8s-validate.yml` admission dry-run, `terraform.yml` Conftest results.
