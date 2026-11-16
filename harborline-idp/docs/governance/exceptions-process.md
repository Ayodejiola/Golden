# Exceptions and risk acceptance

Guardrails can be wrong for a specific case. The exceptions process makes deviations **explicit, time-boxed and
visible** instead of silent.

## Process

1. Open a **Platform request** issue (type *Policy exception*) describing: the control, why it blocks you, the
   compensating controls, data classification, and the requested end date (≤ 6 months).
2. Security Architecture assesses risk (likelihood × impact) and either rejects, approves, or proposes a platform
   change instead.
3. Approved exceptions get an ID (`EXC-####`) and are implemented in code with the ID referenced next to the change
   (resource tag `exception = "EXC-####"`, Kyverno `PolicyException` in the `kyverno` namespace, firewall rule name, etc.).
4. Exceptions are reviewed monthly; expired exceptions fail the Conftest/Kyverno checks again.

## Register

| ID | Control | Scope | Compensating controls | Owner | Expires |
|---|---|---|---|---|---|
| EXC-0001 | ADR-0007 / Conftest: PostgreSQL password authentication | Backstage database (`psql-plat-prod-cac-01`) | Private endpoint only, dedicated server with no customer data, password 40 chars in Key Vault rotated every 90 days, pgaudit, Entra admin via PIM | Platform Product | 2027-05-31 |

## Risk acceptances

| ID | Risk | Owner | Review |
|---|---|---|---|
| RA-0003 | etcd secrets encrypted with platform-managed keys, not CMK (KMS requires API Server VNet Integration) | AKS SME | Roadmap R2 |
| RA-0004 | Azure Monitor ingestion over public endpoints (Entra-authenticated) until AMPLS | SRE | Roadmap R2 |

## Kyverno exception template

```yaml
apiVersion: kyverno.io/v2
kind: PolicyException
metadata:
  name: exc-0000-example
  namespace: kyverno        # only this namespace is honoured (features.policyExceptions.namespace)
  annotations:
    harborline.io/exception-id: EXC-0000
    harborline.io/expires: "2027-01-31"
spec:
  exceptions:
    - policyName: restrict-image-registries
      ruleNames: [require-digest]
  match:
    any:
      - resources:
          kinds: [Pod]
          namespaces: [example-team]
          names: ["legacy-batch-*"]
```
