# ADR-0012: Sigstore signing, SLSA provenance and digest-pinned deploys

- **Status:** Accepted
- **Date:** 2026-11-16
- **Deciders:** DevSecOps, Security Architecture
- **Supersedes / Superseded by:** —

## Context

Supply-chain attacks target build systems and registries. We must prove what runs was built by our pipeline from
reviewed source.

## Decision

All images are built by one reusable **trusted builder** workflow; signed keyless with **Sigstore**; attested with
**SLSA v1 provenance** and an **SPDX SBOM**; deployed **by digest**; verified by **Kyverno at admission**. Third-party
images and charts are scanned and **mirrored into ACR**; clusters cannot reach public registries.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Keyless Sigstore + Kyverno (chosen) | No signing keys to manage; transparency log; identity-bound | Dependency on Sigstore public good instance (Rekor/Fulcio) |
| Notation + Key Vault keys | Azure-native, private trust | Key lifecycle management; Ratify to operate |
| No signing, registry RBAC only | Simple | No provenance; insider/registry compromise undetectable |

## Consequences

Security: SLSA build L3-style guarantees. Reliability: Rekor outage blocks new admissions — documented break-glass in
the image-admission runbook.

## Compliance mapping

NIST CSF GV.SC-07, PR.PS-02; SLSA v1.0.
