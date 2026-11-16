# GitOps (Argo CD)

Each AKS cluster runs its own Argo CD and **pulls** its desired state from this folder (ADR-0004). Nothing pushes
into clusters; the private API servers never need to be reachable from CI.

```text
gitops/
├── bootstrap/root-<env>.yaml        # the only manifest ever applied by hand (scripts/bootstrap-argocd.sh)
├── projects/                        # platform AppProject (tenant AppProjects live in tenants/<team>/base)
├── clusters/<env>/                  # what each cluster runs (app of apps)
│   ├── addons-helm.yaml             # ApplicationSet: Argo CD, Kyverno, OTel Collector, Backstage — versions pinned per env
│   ├── addons-manifests.yaml        # ApplicationSet: Kyverno policies, platform-config overlay
│   ├── tenants.yaml                 # ApplicationSet: one app per gitops/tenants/<team>
│   └── workloads.yaml               # ApplicationSet: one app per gitops/workloads/<env>/<team>/<app>/config.yaml
├── addons/<addon>/values[-<env>].yaml
├── addons/platform-config/          # internal NGINX controller, SecretProviderClasses, PodMonitors, shared roles
├── tenants/<team>/{base,overlays/<env>}  # namespace, quota, limits, default-deny, RBAC
└── workloads/<env>/<team>/<app>/{config,values}.yaml
```

## Flows

| Change | Who | How |
|---|---|---|
| New service version (dev) | CI bot | `app-*.yml` commits the new `image.digest` to `workloads/dev/...` |
| Promote to stg/prod | Team | `promote.yml` opens a PR copying the digest; code owners approve |
| Add-on upgrade | Platform | bump `version` in `clusters/dev/addons-helm.yaml`, soak, then stg, then prod |
| New tenant | Team via Backstage | "Tenant onboarding" template opens a PR adding `tenants/<team>` + AppProject |
| Policy change | Security | PR to `platform/policies/kyverno` with tests; syncs to all clusters |

## Guardrails

- AppProjects stop tenants from creating cluster-scoped objects or editing their own quotas/RBAC.
- `applicationsetcontroller.policy: create-update` — ApplicationSets never delete Applications.
- Tenants are never auto-pruned (`prune: false` on the tenants ApplicationSet).
- Prod has sync windows (no automatic syncs evenings/weekends, manual sync allowed for incidents).
- All images come from ACR by digest and are signature-verified by Kyverno at admission.
