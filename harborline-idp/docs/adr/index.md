# Architecture Decision Records

ADRs capture decisions that are expensive to change. Process: propose with the Backstage **ADR** template
(or `/new-adr` in Claude Code), review in a PR with Cloud Architecture + affected owners, accept on merge.

| ADR | Decision | Status |
|---|---|---|
| [ADR-0001](0001-use-aks-as-the-container-platform.md) | Use AKS as the container platform | Accepted |
| [ADR-0002](0002-terraform-with-thin-in-house-modules-and-per-stack-state.md) | Terraform with thin in-house modules and per-stack state | Accepted |
| [ADR-0003](0003-hub-spoke-network-with-azure-firewall-and-private-only-paas.md) | Hub-spoke network with Azure Firewall and private-only PaaS | Accepted |
| [ADR-0004](0004-gitops-with-argo-cd-pull-based-per-cluster.md) | GitOps with Argo CD, pull-based, one instance per cluster | Accepted |
| [ADR-0005](0005-workload-identity-everywhere-no-long-lived-secrets.md) | Workload identity everywhere; no long-lived secrets | Accepted |
| [ADR-0006](0006-azure-cni-overlay-powered-by-cilium.md) | Azure CNI Overlay powered by Cilium | Accepted |
| [ADR-0007](0007-postgresql-flexible-server-with-entra-only-authentication.md) | PostgreSQL Flexible Server with Entra-only authentication | Accepted |
| [ADR-0008](0008-service-bus-premium-with-transactional-outbox.md) | Azure Service Bus Premium with a transactional outbox | Accepted |
| [ADR-0009](0009-opentelemetry-standard-with-azure-monitor-backend.md) | OpenTelemetry as the telemetry standard, Azure Monitor as backend | Accepted |
| [ADR-0010](0010-backstage-as-the-developer-portal.md) | Backstage as the developer portal | Accepted |
| [ADR-0011](0011-layered-admission-control-kyverno-and-azure-policy.md) | Layered admission control: Kyverno plus Azure Policy | Accepted |
| [ADR-0012](0012-sigstore-signing-slsa-provenance-and-digest-pinned-deploys.md) | Sigstore signing, SLSA provenance and digest-pinned deploys | Accepted |
| [ADR-0013](0013-github-hosted-runners-with-azure-private-networking.md) | GitHub-hosted runners with Azure private networking | Accepted |
| [ADR-0014](0014-ai-assisted-development-with-claude-code-and-mcp-under-guardrails.md) | AI-assisted development with Claude Code and MCP under guardrails | Accepted |
| [ADR-0015](0015-app-gateway-waf-in-front-of-internal-managed-nginx.md) | Application Gateway WAF v2 in front of internal managed NGINX | Accepted |

Template: [0000-template.md](0000-template.md).
