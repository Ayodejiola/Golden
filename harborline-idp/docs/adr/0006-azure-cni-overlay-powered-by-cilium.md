# ADR-0006: Azure CNI Overlay powered by Cilium

- **Status:** Accepted
- **Date:** 2026-11-16
- **Deciders:** AKS SME, Network Engineering
- **Supersedes / Superseded by:** —

## Context

Flat Azure CNI consumes a VNet IP per pod and exhausts address space; kubenet is being retired. We need network
policy enforcement at scale.

## Decision

Use **Azure CNI Overlay** with the **Cilium dataplane and network policy** (`network_data_plane = "cilium"`).

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| CNI Overlay + Cilium (chosen) | Address-efficient, eBPF performance, network policy built-in, observability options | Some Cilium features require Advanced Container Networking Services |
| Azure CNI (flat) | Pods routable on VNet | IP exhaustion; large subnets |
| CNI Overlay + Calico | Mature policy engine | Extra component to operate; iptables performance |

## Consequences

Performance: eBPF dataplane. Security: enforced default-deny. Operations: managed by AKS.

## Compliance mapping

CIS AKS 5.4.4 (network policy).
