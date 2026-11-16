# ADR-0009: OpenTelemetry as the telemetry standard, Azure Monitor as backend

- **Status:** Accepted
- **Date:** 2026-11-16
- **Deciders:** SRE
- **Supersedes / Superseded by:** —

## Context

Teams used mixed agents and SDKs; cross-service traces were impossible.

## Decision

Instrument with **OpenTelemetry SDKs** only; route all telemetry through an in-cluster **OTel Collector**; store traces
and logs in **Application Insights / Log Analytics**, metrics in **Azure Monitor managed Prometheus**, visualise in
**Azure Managed Grafana** (internet-reachable with Entra ID + Conditional Access until private access is enabled).

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| OTel + Azure Monitor (chosen) | Vendor-neutral instrumentation, managed backends, Entra integration | Collector to operate; AMPLS pending |
| Azure Monitor distro only | Simplest | Couples code to vendor; no central redaction |
| Self-hosted Grafana stack | Full control | Significant ops burden and HA work |

## Consequences

Operations: one convention for all services. Security: central PII redaction in the collector.

## Compliance mapping

NIST CSF DE.CM-01/03/09, DE.AE-03.
