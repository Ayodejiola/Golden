# ADR-0013: GitHub-hosted runners with Azure private networking

- **Status:** Accepted
- **Date:** 2026-11-16
- **Deciders:** DevSecOps, Network Engineering
- **Supersedes / Superseded by:** —

## Context

Pipelines need to reach private endpoints (ACR, Key Vault, AKS for bootstrap) without public exposure, and we do not
want to operate runner VMs.

## Decision

Use **GitHub-hosted runners with Azure private networking** (`GitHub.Network/networkSettings`) injected into a
delegated subnet per environment spoke, organised into runner groups `harborline-build`, `harborline-dev|stg|prod`.
Egress is forced through the hub firewall with a CI allow-list.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Hosted runners + private networking (chosen) | No VMs to patch, ephemeral, private reach | Requires GitHub Enterprise Cloud; per-minute cost |
| Actions Runner Controller on AKS | Cheap at scale | Runners share clusters with workloads; we operate it |
| Self-hosted VM scale set | Full control | Patching, image management, persistence risk |

## Consequences

Security: ephemeral runners, network-scoped per environment. Cost: higher per-minute price, no idle cost.

## Compliance mapping

NIST CSF PR.PS-04, PR.IR-01.
