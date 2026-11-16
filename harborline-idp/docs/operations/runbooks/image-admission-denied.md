# Image or pod denied by admission policy

| | |
|---|---|
| **Alerts / trigger** | `KyvernoAdmissionFailuresHigh`, Argo CD sync errors mentioning Kyverno or Gatekeeper |
| **Owner** | Owning team; Platform for policy bugs |

Kyverno or Azure Policy rejected a resource. This is usually the guardrail working: unsigned image, tag instead of digest, non-ACR registry, missing labels or a pod security violation.

## Diagnose (read-only)

```bash
kubectl get events -n <ns> --field-selector reason=PolicyViolation --sort-by=.lastTimestamp | tail
kubectl get policyreport -n <ns> -o wide
cosign verify --certificate-identity-regexp '^https://github\.com/harborline/.+@refs/heads/main$' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com <image@digest>
```

## Mitigate

1. **Signature/provenance failure:** the image was not built by the trusted builder on `main` — rebuild via the pipeline; never re-tag manually.
2. **Digest/registry:** use the GitOps values written by CI; third-party images must be mirrored (`platform/mirror/artifacts.yaml`).
3. **Pod security:** fix the chart values; do not request privileged containers.
4. **Sigstore outage (Rekor/Fulcio):** running pods are unaffected. For an urgent deploy Security may approve a time-boxed `PolicyException` (≤ 24 h) in the `kyverno` namespace referencing the incident.
5. Suspected policy bug: reproduce with `kyverno test` / `kyverno apply` and open a PR with a failing test.

## Verify

Resources admitted; Argo CD Synced; no new PolicyViolation events.

## Escalate

Page the next tier in [on-call](../oncall.md) if not mitigated within 30 minutes (SEV1) or 2 hours (SEV2). Record
actions in the incident timeline.
