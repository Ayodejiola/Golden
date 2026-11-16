# Argo CD application out of sync or degraded

| | |
|---|---|
| **Alerts / trigger** | `ArgoCDAppOutOfSync` |
| **Owner** | Platform primary (platform apps) / owning team (workloads) |

An Application stayed OutOfSync or Degraded for 30 minutes. Common causes: admission denial (Kyverno/Azure Policy), invalid values, failed PreSync migration, sync window, or Git/registry access.

## Diagnose (read-only)

```bash
argocd app list -p <project>
argocd app get <app> --show-operation
kubectl -n argocd get applications <app> -o jsonpath='{.status.conditions}' | jq
kubectl get events -n <namespace> --sort-by=.lastTimestamp | tail -30
kubectl -n <namespace> get jobs,pods -l app.kubernetes.io/name=<app>-migrations
```

## Mitigate

1. **Admission denied:** read the message; it names the policy. Fix the manifest/values in Git (see [image admission denied](image-admission-denied.md)).
2. **PreSync migration failed:** read job logs; fix forward with a new migration — never edit an applied migration (checksum guard).
3. **Sync window:** prod denies auto-sync outside business hours; for incidents an admin can sync manually (logged).
4. **Repo/registry access:** check the GitHub App secret and the repo-server workload identity (`AcrPull`).
5. Rollback: revert the GitOps PR; Argo CD syncs the previous state.

## Verify

Application Synced + Healthy; alert resolved.

## Escalate

Page the next tier in [on-call](../oncall.md) if not mitigated within 30 minutes (SEV1) or 2 hours (SEV2). Record
actions in the incident timeline.
