---
description: Produce or update a STRIDE threat model for a service or platform change
argument-hint: <service name or path>
---

Threat-model **$ARGUMENTS** using Harborline's method (`docs/security/threat-model-platform.md` is the reference).

1. Identify assets, actors, entry points and trust boundaries from the code, Helm values, Terraform and
   `catalog-info.yaml`. Draw a Mermaid data-flow diagram with trust boundaries as subgraphs.
2. Enumerate threats per element with STRIDE. For each: likelihood (1–5), impact (1–5), existing control
   (link the file that implements it), gap, and recommended mitigation.
3. Map mitigations to NIST CSF 2.0 subcategories and OWASP ASVS 5.0 chapters.
4. Put the result in `docs/security/threat-model-<name>.md`. Never include real customer data or secrets.
5. Finish with the top 5 residual risks and proposed owners. Flag anything rated ≥ 15 as a release blocker.
