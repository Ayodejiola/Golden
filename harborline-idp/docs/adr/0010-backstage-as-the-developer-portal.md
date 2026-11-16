# ADR-0010: Backstage as the developer portal

- **Status:** Accepted
- **Date:** 2026-11-16
- **Deciders:** Platform Product
- **Supersedes / Superseded by:** —

## Context

Engineers spend days finding owners, docs and the right way to start a service. Platform-as-product needs a front door.

## Decision

Run **Backstage** (new backend + frontend systems) in the prod platform cluster with Entra sign-in, Microsoft Graph org
sync, GitHub discovery, TechDocs (local builder), Kubernetes plugin (workload identity, read-only) and Software Templates
for golden paths. Backstage reaches other clusters' private API servers through an explicit firewall rule.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Backstage (chosen) | Open source, extensible, CNCF, catalog + templates + docs in one | Needs a team to own it; upgrades monthly |
| Commercial IDP (e.g. Port, Cortex) | Faster start, SaaS | Data leaves our tenant; less customisation |
| Wiki + scripts | Cheap | No catalog, no self-service, docs rot |

## Consequences

Operations: portal is itself delivered on the golden path. Security: EXC-0001 database password until Entra token auth
is validated for the Backstage backend.

## Compliance mapping

NIST CSF ID.AM-01/02 (inventory), GV.RR.
