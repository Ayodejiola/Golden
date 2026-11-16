# ADR-0005: Workload identity everywhere; no long-lived secrets

- **Status:** Accepted
- **Date:** 2026-11-16
- **Deciders:** Security Architecture, Platform Engineering
- **Supersedes / Superseded by:** —

## Context

Leaked credentials are the leading cause of cloud breaches. Connection strings and SAS keys are hard to rotate and audit.

## Decision

All workloads authenticate to Azure with **Entra Workload ID** (federated UAMI per service account). CI uses **GitHub
OIDC**. PostgreSQL and Service Bus use Entra authentication with local/password auth disabled. Key Vault (via CSI) is
reserved for third-party secrets that cannot be federated. Exceptions are registered (EXC-####) with expiry.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Workload identity (chosen) | No secret to steal or rotate; per-pod identity; auditable | Each service needs Terraform for its identity |
| Key Vault + CSI for connection strings | Simple app code | Secrets still exist and leak via env/logs |
| Kubelet identity shared | Zero setup | No least privilege; any pod gets node rights |

## Consequences

Security: removes the credential theft class. Operations: identity creation becomes part of the golden path.

## Compliance mapping

NIST CSF PR.AA-01..05; CIS AKS 5.2.1, 4.4.x; OWASP ASVS V13.
