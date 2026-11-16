# Data classification and handling

| Class | Examples | Storage | Telemetry / events | AI tools |
|---|---|---|---|---|
| **Public** | Marketing content, published rates | Any approved store | Allowed | Allowed |
| **Internal** | Architecture docs, non-sensitive config, service metadata | Harborline tenant only | Allowed | Allowed (Claude via approved enterprise terms) |
| **Confidential** | Aggregated financials, security findings, platform logs | Private endpoints, Canada regions | Allowed without customer identifiers | Allowed without secrets; no raw logs from prod |
| **Restricted** | Policyholder PII, claim narratives, health info, payment data | Encrypted at rest + in transit, Canada only, private endpoints, access via PIM | **Never**: IDs only, masked/redacted | **Never** — use synthetic fixtures |

## Rules for restricted data

1. Lives only in the system of record (PostgreSQL) in Canada Central / Canada East.
2. Never in logs, traces, metrics, events, tickets, chat, screenshots or AI prompts.
3. Accessed by humans only through approved applications or PIM-elevated break-glass with pgaudit trail.
4. Non-production environments use **synthetic data only** (no copies of production).
5. Retention follows the records schedule (policies: 7 years after expiry; claims: 10 years after closure).

## Labels

- Azure: `data-classification` tag on resource groups and resources.
- Kubernetes: `harborline.io/data-classification` on namespaces and pods.
- Backstage: `harborline.io/data-classification` annotation on systems/components.

These labels drive policy (e.g. stricter egress for `restricted` namespaces) and are required by Kyverno.
