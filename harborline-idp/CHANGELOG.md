# Changelog

All notable changes to the Harborline IDP are recorded here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning: [SemVer](https://semver.org/) for the platform contract (golden-service chart values, template parameters,
Terraform module interfaces).

## [Unreleased]

## [1.0.0] - 2026-11-16

### Added

- Terraform modules and stacks for an Azure Landing Zone–aligned hub-spoke topology: Azure Firewall Premium, central
  private DNS, private AKS (Azure CNI Overlay + Cilium, workload identity, Entra RBAC, KMS, Defender, Azure Policy),
  ACR Premium, Key Vault, Application Gateway WAF v2, PostgreSQL Flexible Server (Entra-only auth, zone-redundant HA),
  Service Bus Premium, managed Prometheus, Managed Grafana and Application Insights.
- `golden-service` Helm chart v1.0.0 with restricted pod security, workload identity, KEDA, PDB, topology spread,
  default-deny network policy and migration hooks.
- Kyverno policy set with CLI tests; Conftest rules for Terraform plans.
- Argo CD bootstrap, AppProjects and ApplicationSets for add-ons, tenants and workloads across dev/stg/prod.
- GitHub Actions: Terraform plan/apply with OIDC, reusable secure container build (CodeQL, Trivy, Gitleaks, SBOM,
  Sigstore signing, SLSA provenance), digest-based promotion, policy validation, docs, drift detection, AI review.
- Backstage portal with catalog, three software templates and TechDocs.
- Reference 3-tier insurance application (React, FastAPI, claims worker, PostgreSQL, Service Bus outbox).
- Platform MCP server and Claude Code guardrails (permissions, hooks, audit trail, slash commands, sub-agents).
- Architecture documentation, 15 ADRs, threat models, NIST CSF 2.0 / CIS AKS / OWASP ASVS 5.0 mappings,
  governance standards, SLOs, 14 runbooks and DR plan.
