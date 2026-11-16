# ADR-0011: Layered admission control: Kyverno plus Azure Policy

- **Status:** Accepted
- **Date:** 2026-11-16
- **Deciders:** Security Architecture
- **Supersedes / Superseded by:** —

## Context

We need in-cluster enforcement (pod security, image provenance, tenancy rules) and Azure-level compliance reporting.

## Decision

Use **Azure Policy for AKS** (Gatekeeper) for compliance-reported baselines (PSS restricted initiative, allowed images,
private cluster, no external LB) — Audit in dev, Deny above — and **Kyverno** for Harborline-specific rules: signature +
provenance verification, digest pinning, labels, tenancy boundaries, RBAC hygiene and generated defaults. Policies ship
with CLI tests.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Kyverno + Azure Policy (chosen) | Defence in depth; Kyverno verifyImages and generate; Defender/Policy compliance view | Two engines to understand |
| Azure Policy only | Single engine | No image signature verification or generation; custom Rego authoring |
| Kyverno only | Single engine, YAML policies | No Azure compliance reporting |

## Consequences

Security: two independent layers. Operations: policy tests in CI; exceptions only from the `kyverno` namespace.

## Compliance mapping

CIS AKS 4.2.x, 4.6.x, 5.1.4; NIST CSF PR.PS-01/02.
