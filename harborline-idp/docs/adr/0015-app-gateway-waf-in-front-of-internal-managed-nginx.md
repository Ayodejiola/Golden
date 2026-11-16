# ADR-0015: Application Gateway WAF v2 in front of internal managed NGINX

- **Status:** Accepted
- **Date:** 2026-11-16
- **Deciders:** Network Engineering, Security Architecture, AKS SME
- **Supersedes / Superseded by:** —

## Context

Public endpoints need OWASP-grade WAF protection; clusters must not expose public load balancers; certificates should
come from Key Vault.

## Decision

Terminate public TLS on **Application Gateway WAF_v2** (DRS 2.1 + Bot Manager, Prevention mode, geo-filter, rate limit)
and forward over TLS to an **internal-only managed NGINX** (AKS app routing add-on, default public controller disabled)
with Key Vault certificates. Tenants may only use the `nginx-internal` ingress class; snippet annotations are blocked.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| AGW WAF + internal NGINX (chosen) | Proven, WAF owned by Security, no public LB in cluster | Two hops; AGW config through Terraform |
| Application Gateway for Containers | Gateway API, tighter K8s integration | Newer; WAF integration maturity at decision time |
| Front Door Premium + Private Link | Global edge, DDoS at edge | Cost and complexity for single-region audience |

## Consequences

Security: OWASP protection at the edge, no in-cluster public exposure. Performance: one extra TLS hop (acceptable).

## Compliance mapping

OWASP ASVS V3/V4 (edge controls), CIS AKS 5.4.5, NIST CSF PR.IR-01.
