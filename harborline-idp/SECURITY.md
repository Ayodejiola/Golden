# Security Policy

## Reporting a vulnerability

Do **not** open a public issue. Report privately via GitHub Security Advisories on this repository
("Report a vulnerability") or to the Security Operations Centre at `soc@harborline.example` (PGP key on the intranet).
We acknowledge within 1 business day and triage within 3.

| Severity (CVSS v4) | Fix target in production |
|---|---|
| Critical (9.0–10) | 72 hours, or compensating control within 24 hours |
| High (7.0–8.9) | 14 days |
| Medium (4.0–6.9) | 45 days |
| Low | Next planned release |

## Supported versions

Only `main` and the latest tagged release of the platform contract are supported.

## Scope

In scope: everything in this repository and the environments it deploys. Out of scope: third-party SaaS
(GitHub, Microsoft) — report those to the vendor and tell us.

See `docs/security/` for threat models, the controls matrix and the vulnerability management standard.
