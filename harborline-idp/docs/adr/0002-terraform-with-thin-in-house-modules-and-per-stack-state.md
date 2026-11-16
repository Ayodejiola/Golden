# ADR-0002: Terraform with thin in-house modules and per-stack state

- **Status:** Accepted
- **Date:** 2026-11-16
- **Deciders:** Platform Engineering, Cloud Architecture
- **Supersedes / Superseded by:** —

## Context

Infrastructure must be reviewable, testable and promotable across environments. ALZ core (management groups, global
policy) is already delivered by the enterprise ALZ accelerator built on Azure Verified Modules (AVM).

## Decision

Use **Terraform (azurerm 4.x, azapi 2.x)** with thin, opinionated in-house modules composed into **stacks**
(`bootstrap`, `management`, `connectivity`, `platform`, `workload-*`), each with its own state per environment and
environment-specific `tfvars`. Stacks discover each other by naming convention, not remote state. Consume AVM for ALZ
core; revisit AVM resource modules when they cover our hardening defaults without wrappers.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| In-house thin modules (chosen) | Defaults encode Harborline controls; small surface; easy review | We maintain them; must track provider changes |
| AVM resource modules directly | Microsoft-supported, consistent interfaces | Large interfaces, defaults differ from our baseline; wrappers anyway |
| Bicep | Native, day-0 API support | Weaker multi-provider story (GitHub, random), less tooling for plan policy |

## Consequences

Reliability/Operations: small state files limit blast radius and lock contention. Security: plan-time Conftest and
Checkov; read-only plan identities. Cost: none significant.

## Compliance mapping

NIST CSF GV.PO, PR.PS-01 (configuration management).
