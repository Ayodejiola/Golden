# ADR-0001: Use AKS as the container platform

- **Status:** Accepted
- **Date:** 2026-11-16
- **Deciders:** Platform Engineering, Cloud Architecture, AKS SME
- **Supersedes / Superseded by:** —

## Context

Harborline runs ~40 services today on a mix of App Service and VMs, with inconsistent security baselines and no
self-service. We need one runtime that supports long-running APIs, event-driven workers and batch jobs, with strong
isolation, policy enforcement and a large ecosystem (GitOps, policy engines, OpenTelemetry).

## Decision

Adopt **Azure Kubernetes Service** (private clusters, one per environment) as the default runtime for containerised
workloads. Azure Container Apps remains an option for simple, low-criticality workloads via an exception.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| AKS (chosen) | Full Kubernetes API, mature ecosystem, Azure-managed control plane, Defender/Policy integration, KEDA/VPA add-ons | Operational complexity; platform team must own upgrades, add-ons, multi-tenancy |
| Azure Container Apps | Serverless, minimal ops, built-in KEDA and Dapr | Limited control over networking and admission policy; less portable; fewer tenancy controls |
| App Service | Simple PaaS, familiar | Poor fit for workers and event-driven scaling; per-app hardening drift |

## Consequences

Reliability: zonal node pools and PDBs; we own upgrade discipline. Security: private API server, Entra RBAC, admission
control. Cost: shared nodes improve density but require chargeback. Operations: platform team needed (accepted).
Performance: Cilium dataplane, fine-grained autoscaling.

## Compliance mapping

NIST CSF PR.PS, PR.IR; CIS AKS Benchmark applies in full.
