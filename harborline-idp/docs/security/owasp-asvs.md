# OWASP ASVS 5.0 mapping (target: Level 2)

Applies to every service built from the golden path; examples reference the reference app
(`apps/insurance/policy-api`, `web`) and platform components. Chapter titles follow ASVS 5.0.

| Chapter | Harborline implementation | Where |
|---|---|---|
| V1 Encoding and Sanitization | Parameterised SQL only; React output encoding; no server-side templating of user input | `repository.py`, `web/src` |
| V2 Validation and Business Logic | Strict pydantic models (`extra="forbid"`, enums, ranges); business rules (bind once, quote expiry, loss date in policy period) under row locks | `models.py`, `repository.py` |
| V3 Web Frontend Security | CSP `default-src 'self'`, `frame-ancestors 'none'`, COOP, Referrer-Policy, HSTS at WAF, no inline script | `web/nginx/templates`, WAF rewrite rules |
| V4 API and Web Service | Versioned REST, RFC 9457 errors, content-type enforcement, 1 MB body limit, rate limiting at WAF | `main.py`, ingress annotations, WAF policy |
| V5 File Handling | No file uploads in the reference app; platform WAF limits upload size (25 MB) | `modules/app-gateway-waf` |
| V6 Authentication | Delegated to Entra ID (phishing-resistant MFA via Conditional Access); no local credentials | Entra, MSAL (`web/src/auth.ts`) |
| V7 Session Management | Stateless bearer tokens; SPA keeps tokens in sessionStorage (cleared with the tab); no server sessions | `web/src/auth.ts` |
| V8 Authorization | Scope/app-role checks on every route; object ownership enforced in queries; deny by default | `security.py`, `auth.authorize`, `repository.py` |
| V9 Self-contained Tokens | RS256 only, JWKS validation, `iss`/`aud`/`tid`/`exp`/`nbf` required, algorithm-confusion test | `auth.py`, `tests/test_auth.py` |
| V10 OAuth and OIDC | Authorization code + PKCE (MSAL), exact redirect URIs, audience-restricted access tokens | Entra app registrations, `auth.ts` |
| V11 Cryptography | Platform-managed TLS and encryption at rest; Key Vault Premium (HSM) for keys; no custom crypto | modules `key-vault`, `postgresql` |
| V12 Secure Communication | TLS 1.2+ at WAF and PostgreSQL (`require_secure_transport`), AMQP over TLS to Service Bus | WAF SSL policy, PG parameters |
| V13 Configuration | Fail-fast unsafe-config checks; no secrets in config; read-only containers; minimal images | `config.py`, Dockerfiles, chart |
| V14 Data Protection | PII masking/redaction, data minimisation in events, `no-store` caching for API, classification labels | `pii.py`, `messaging.py`, `security.py` |
| V15 Secure Coding and Architecture | Threat models, dependency scanning, SBOMs, least-privilege identities, layered architecture | `docs/security/`, CI |
| V16 Security Logging and Error Handling | JSON logs with trace/correlation IDs, auth failures logged without tokens, generic errors | `logging_config.py`, `main.py` |
| V17 WebRTC | Not applicable | — |

## Verification

- Unit tests encode abuse cases (`policy-api/tests`); integration tests verify ownership checks.
- CodeQL `security-extended` on every PR; ZAP baseline scan against stg is on the roadmap (R2).
- Level 3 controls (e.g. column-level encryption of PII) are tracked per service via the threat model.
