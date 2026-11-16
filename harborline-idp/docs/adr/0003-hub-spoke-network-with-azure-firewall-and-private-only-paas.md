# ADR-0003: Hub-spoke network with Azure Firewall and private-only PaaS

- **Status:** Accepted
- **Date:** 2026-11-16
- **Deciders:** Network Engineering, Security Architecture
- **Supersedes / Superseded by:** —

## Context

Insurance data is restricted; regulators expect network segmentation and egress control. ALZ recommends hub-spoke or
Virtual WAN.

## Decision

Adopt **hub-spoke** with **Azure Firewall Premium** (IDPS and threat intelligence in Deny mode, DNS proxy), forced
tunnelling from spokes, central Private DNS zones in the hub, and **private endpoints for every PaaS service**. Public
network access is denied by Azure Policy in the Corp landing zones, with ADR-backed exceptions only.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Hub-spoke + Firewall (chosen) | Full control, FQDN filtering, IDPS, mature Terraform | Firewall cost; we manage routing |
| Virtual WAN secured hub | Managed routing at scale, global transit | Less flexibility for custom DNS/UDR; overkill for 2 regions |
| Service endpoints instead of private endpoints | Cheaper, simpler | Traffic still to public IPs; no on-prem access; weaker exfiltration control |

## Consequences

Security: strong egress control and exfiltration resistance. Cost: Firewall Premium is the largest fixed network cost
(accepted for regulated data). Operations: every new external dependency needs an allow-list PR (deliberate friction).

## Compliance mapping

NIST CSF PR.IR-01, DE.CM-01; CIS AKS 5.4.x.
