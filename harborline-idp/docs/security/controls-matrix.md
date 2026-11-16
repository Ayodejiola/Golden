# Security controls matrix (NIST CSF 2.0)

Maps NIST Cybersecurity Framework 2.0 categories to concrete, inspectable implementations in this repository.
Evidence is generated continuously (pipelines, Azure Policy compliance, Defender for Cloud) — auditors should be able
to follow each row to code.

| Function | Category | Implementation | Evidence |
|---|---|---|---|
| **Govern (GV)** | GV.OC Organizational context | Platform charter, data classification, region policy (Canada) | `docs/product/charter.md`, `docs/governance/data-classification.md` |
| | GV.RM Risk management strategy | Threat models, risk register (RA-/EXC-), quarterly review | `docs/security/threat-model-*.md`, `docs/governance/exceptions-process.md` |
| | GV.RR Roles & responsibilities | CODEOWNERS, Backstage ownership, on-call | `.github/CODEOWNERS`, `backstage/catalog/org.yaml`, `docs/operations/oncall.md` |
| | GV.PO Policy | Standards, golden path, AI usage policy | `docs/governance/*`, `docs/ai/usage-policy.md` |
| | GV.OV Oversight | Scorecards, WAF assessment, drift detection | `docs/governance/scorecards.md`, `drift-detection.yml` |
| | GV.SC Supply chain risk | Mirror + scan third-party artefacts, SBOM, signing, Dependabot, dependency review | `platform/mirror/`, `_container-build.yml`, `.github/dependabot.yml` |
| **Identify (ID)** | ID.AM Asset management | Backstage catalog, mandatory tags, Azure Resource Graph | `catalog-info.yaml`, `modules/naming` |
| | ID.RA Risk assessment | STRIDE models, Defender recommendations, Trivy/CodeQL findings | `docs/security/`, GitHub code scanning |
| | ID.IM Improvement | Post-incident reviews, ADRs, roadmap | `docs/operations/incident-management.md`, `docs/adr/` |
| **Protect (PR)** | PR.AA Identity, authN, authZ | Entra + PIM, workload identity, GitHub OIDC, ABAC-constrained delegation, app JWT validation | `docs/architecture/identity-and-access.md`, `stacks/bootstrap`, `policy_api/auth.py` |
| | PR.AT Awareness & training | Golden-path onboarding, AI usage training, secure coding guides | `docs/getting-started.md`, `docs/ai/` |
| | PR.DS Data security | Private endpoints, TLS 1.2+, encryption at rest (+ host), PII masking, data minimisation in events | modules `postgresql`, `service-bus`, `policy_api/pii.py` |
| | PR.PS Platform security | Pod security restricted, Kyverno, Azure Policy, hardened images, patch channels, IaC scanning | `platform/policies/`, `modules/aks`, `.checkov.yaml` |
| | PR.IR Infrastructure resilience | Zones, PDBs, HA PostgreSQL, network segmentation, WAF | `modules/aks`, `golden-service` chart, `modules/app-gateway-waf` |
| **Detect (DE)** | DE.CM Continuous monitoring | Defender for Containers, firewall IDPS, audit logs, SLO alerts, drift detection | `modules/aks/alerts.tf`, `slo.tf`, diagnostic settings |
| | DE.AE Adverse event analysis | Central Log Analytics → SIEM, correlation IDs, distributed tracing | `docs/architecture/observability.md` |
| **Respond (RS)** | RS.MA Incident management | Severity model, on-call, incident commander role | `docs/operations/incident-management.md` |
| | RS.AN Analysis | Runbooks with diagnostics, `/incident-assist` read-only co-pilot | `docs/operations/runbooks/`, `.claude/commands/incident-assist.md` |
| | RS.CO Reporting & communication | Status templates, regulator notification guidance | `docs/operations/incident-management.md` |
| | RS.MI Mitigation | Break-glass, network isolation steps, credential revocation | `docs/operations/runbooks/security-incident-response.md` |
| **Recover (RC)** | RC.RP Recovery plan execution | DR plan, PITR, Git-rebuild of clusters, tested quarterly | `docs/operations/disaster-recovery.md` |
| | RC.CO Recovery communication | Stakeholder comms templates, post-incident review | `docs/operations/incident-management.md` |

See also: [CIS AKS Benchmark mapping](cis-aks-benchmark.md) · [OWASP ASVS mapping](owasp-asvs.md) ·
[Supply chain](supply-chain-security.md)
