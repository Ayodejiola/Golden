# Software supply chain security

Target: **SLSA v1.0 Build Level 3-style guarantees** for first-party images and controlled intake of third-party
artefacts (ADR-0012).

## First-party build

| Step | Control | Tool |
|---|---|---|
| Source | Branch protection, 2 reviews, CODEOWNERS, signed commits, secret scanning | GitHub rulesets, Gitleaks |
| Dependencies | Lock files with hashes, Dependabot, dependency review (fail on high), `pip-audit`, `npm audit` | GitHub, pip-audit |
| Build | Single reusable trusted builder (`_container-build.yml`), ephemeral hosted runners, pinned actions (SHA), least-privilege `permissions:` | GitHub Actions |
| Scan | Trivy image scan (fail on fixable HIGH/CRITICAL), CodeQL SAST, Checkov IaC | Trivy, CodeQL, Checkov |
| SBOM | SPDX JSON for every image, attached as a signed attestation | Syft (anchore/sbom-action), cosign |
| Sign | Keyless Sigstore signature bound to the builder workflow identity on `main` | cosign, Fulcio, Rekor |
| Provenance | SLSA v1 predicate (cosign attestation) + GitHub artifact attestation | cosign, attest-build-provenance |
| Store | Push by digest to private ACR; geo-replicated; untagged retention 30 days | ACR Premium |
| Deploy | Digest-only references in GitOps; promotion re-verifies before PR | `promote.yml` |
| Admit | Kyverno verifies signature identity + issuer and SLSA provenance repository; registry allow-list; digest required | `platform/policies/kyverno` |

Verify any image yourself:

```bash
IMG=acrhblmgmtsharedcac01.azurecr.io/insurance/policy-api@sha256:<digest>
ID='^https://github\.com/harborline/[A-Za-z0-9_.-]+/\.github/workflows/[A-Za-z0-9_.-]+\.ya?ml@refs/heads/main$'
cosign verify --certificate-identity-regexp "$ID" --certificate-oidc-issuer https://token.actions.githubusercontent.com "$IMG"
cosign verify-attestation --type https://slsa.dev/provenance/v1 --certificate-identity-regexp "$ID" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com "$IMG" | jq -r .payload | base64 -d | jq .predicate
gh attestation verify "oci://$IMG" --owner harborline
```

## Third-party intake

1. Add the artefact to `platform/mirror/artifacts.yaml` via PR (Security Architecture review).
2. `mirror-artifacts.yml` scans with Trivy (fail on unwaived CRITICAL) and imports into ACR (`mirror/…`, `helm/…`).
3. Weekly rescans; Renovate/Dependabot propose version bumps; dev clusters adopt first.
4. Waivers live in `.trivyignore` with a risk-acceptance ID and expiry.

## GitHub Actions hardening

- Pin every action to a full commit SHA (`make pin-actions`); Dependabot updates the pins.
- `permissions: contents: read` at workflow level; elevate per job only.
- `persist-credentials: false` on checkout; no `pull_request_target` with untrusted code.
- OIDC for Azure; secrets only for the GitOps GitHub App and the Anthropic API key (AI review).
- OpenSSF Scorecard weekly; findings triaged like vulnerabilities.
