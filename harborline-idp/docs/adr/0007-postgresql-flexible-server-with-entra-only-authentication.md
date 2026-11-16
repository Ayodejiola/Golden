# ADR-0007: PostgreSQL Flexible Server with Entra-only authentication

- **Status:** Accepted
- **Date:** 2026-11-16
- **Deciders:** Insurance Digital, Platform Engineering, DBA
- **Supersedes / Superseded by:** —

## Context

The policy portal needs relational integrity (quotes → policies → claims) and transactional outbox support.

## Decision

Use **Azure Database for PostgreSQL Flexible Server** in **private endpoint mode**, **Entra ID authentication only**,
zone-redundant HA in stg/prod and geo-redundant backups in prod. Schema migrations run as an Argo CD PreSync job under a
dedicated migrator identity that also provisions least-privilege roles for each app identity.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| PG Flexible, Entra-only (chosen) | Managed HA/backups, passwordless, PE mode fits hub DNS | Token refresh handling in apps |
| Azure SQL | Mature Entra auth | Team skills and tooling are PostgreSQL |
| Cosmos DB | Global scale | Relational constraints and outbox harder |

## Consequences

Reliability: ZR HA, PITR 35 days. Security: no passwords, pgaudit. Cost: GP SKUs in prod only.

## Compliance mapping

NIST CSF PR.DS-01/02, PR.AA-05; OWASP ASVS V14.
