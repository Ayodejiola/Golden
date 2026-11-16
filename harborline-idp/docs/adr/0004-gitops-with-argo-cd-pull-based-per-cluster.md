# ADR-0004: GitOps with Argo CD, pull-based, one instance per cluster

- **Status:** Accepted
- **Date:** 2026-11-16
- **Deciders:** Platform Engineering, SRE
- **Supersedes / Superseded by:** —

## Context

Clusters are private. Push-based CD would require CI to hold cluster credentials and network reach into every spoke.

## Decision

Run **Argo CD in each cluster**, reconciling from `gitops/` in this repository via an app-of-apps root, ApplicationSets
for add-ons, tenants and workloads, and AppProjects as tenant guardrails. CI only writes to Git.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Argo CD per cluster (chosen) | No inbound access needed, blast radius per env, strong UI/RBAC, ApplicationSets | N instances to upgrade (handled by GitOps itself) |
| Central Argo CD managing all clusters | Single pane | Needs network + credentials to every API server; prod blast radius |
| Flux (AKS GitOps extension) | Managed extension | Weaker multi-tenant UI; teams preferred Argo CD UX |

## Consequences

Security: CI never holds kube credentials. Reliability: self-healing drift correction. Operations: Argo CD manages its
own upgrades through the same pipeline.

## Compliance mapping

NIST CSF PR.PS-01, DE.CM-09 (drift).
