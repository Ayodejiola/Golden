# Reference app: Harborline Policy Portal

A three-tier insurance application that exercises every part of the golden path. Code: `apps/insurance/`.

| Tier | Component | Tech | Notes |
|---|---|---|---|
| Presentation | `web` | React 19 + Vite, MSAL, unprivileged NGINX | Strict CSP, runtime `/config.json`, read-only rootfs |
| Application | `policy-api` | Python 3.12, FastAPI, pydantic v2 | Entra JWT validation, scope/role authZ, rating engine, outbox relay, RFC 9457 errors |
| Async | `claims-worker` | Python 3.12, azure-servicebus | CloudEvents consumer, idempotent inbox, triage rules, KEDA scaling |
| Data | PostgreSQL Flexible Server | Entra-only auth | Migrations as Argo CD PreSync hook, least-privilege roles |
| Messaging | Service Bus Premium | Topics `claims`, `policies` | DLQ, duplicate detection, SQL filter |

## Domain

- **Products:** personal auto and home insurance in Canadian provinces (auto not offered where a public insurer
  operates: BC, MB, SK).
- **Quote → bind → claim (FNOL) → triage** (fast-track, adjuster review, SIU review).
- Rating and triage are deterministic, documented rules in pure functions with unit tests.

## API

`POST /api/v1/quotes`, `POST /api/v1/policies`, `GET /api/v1/policies[/{number}]`, `POST /api/v1/claims`,
`GET /api/v1/claims/{number}` — contract in `apps/insurance/policy-api/openapi.yaml` (registered in Backstage).

## Quality gates

38 unit tests for the API (rating, validation, auth incl. algorithm confusion, PII masking, outbox, config safety),
10 for the worker (triage rules, idempotency, poison handling), an integration test against real PostgreSQL in CI, and
web client tests (vitest).

## Run locally

```bash
make app-up        # http://localhost:8081 (web), http://localhost:8080/api/docs (API)
make app-test
```

Threat model: [threat-model-insurance-app.md](../security/threat-model-insurance-app.md).
