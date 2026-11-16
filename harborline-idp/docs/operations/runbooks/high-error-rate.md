# High error rate / availability burn

| | |
|---|---|
| **Alerts / trigger** | `PolicyApiAvailabilityFastBurn`, `PolicyApiAvailabilitySlowBurn`, `KubePodCrashLooping`, `KubeDeploymentReplicasMismatch`, `KubeContainerOOMKilled` |
| **Owner** | Owning team |

The service is returning 5xx faster than the error budget allows, or pods are crash-looping or unavailable.

## Diagnose (read-only)

```bash
kubectl -n <ns> get pods -l app.kubernetes.io/name=<app>
kubectl -n <ns> describe pod <pod> | tail -30
kubectl -n <ns> logs <pod> --previous --tail=100
argocd app history <team>-<app>
# App Insights (KQL)
# requests | where timestamp > ago(30m) and success == false | summarize count() by name, resultCode | top 10 by count_
```

## Mitigate

1. **Recent deploy?** Roll back first: revert the GitOps PR (or promote the previous digest). Investigate after.
2. **Dependency failing?** Check readiness detail and the PostgreSQL / Service Bus runbooks; check Entra ID health.
3. **OOMKilled?** Raise the memory limit via a values PR; check for leaks with VPA recommendations.
4. **Traffic spike?** Confirm the HPA scaled (`kubectl get hpa`); WAF rate limiting may be shedding abusive load.

## Verify

Burn rate below 1× for 30 minutes; pods Ready; no restarts.

## Escalate

Page the next tier in [on-call](../oncall.md) if not mitigated within 30 minutes (SEV1) or 2 hours (SEV2). Record
actions in the incident timeline.
