# Roadmap

Now / next / later — reviewed monthly with customer teams. Items reference risks (RA-), exceptions (EXC-) and ADRs.

## Now — R1 (current release, 1.0)

- Golden path GA: Python API template, tenant onboarding, golden-service chart 1.0, trusted builder, promotion.
- Private AKS baseline in dev/stg/prod; Kyverno + Azure Policy; WAF ingress.
- OTel + Azure Monitor + Grafana; SLO-as-code for tier-1 services.
- Backstage with catalog, templates, TechDocs, Kubernetes plugin.
- Claude Code guardrails and platform-catalog MCP.

## Next — R2 (next two quarters)

| Item | Why |
|---|---|
| API Server VNet Integration + KMS with CMK | Close RA-0003 (CIS 5.3.1) |
| Azure Monitor Private Link Scope | Close RA-0004 |
| Backstage Entra token auth to PostgreSQL | Close EXC-0001 |
| Tail sampling via load-balancing collector tier | Better traces at lower cost |
| k6 load-test gate and OWASP ZAP baseline in stg | Performance + DAST evidence |
| Node.js and Java service templates | Cover 80% of teams |
| Scorecards plugin in Backstage | Make GP compliance visible |
| Dev cluster scheduled stop (nights/weekends) | Cost |

## Later — R3+

- Warm-standby DR region for tier-0 services (RTO 1 h).
- Application Gateway for Containers / Gateway API evaluation.
- Ephemeral preview environments per PR (vCluster or namespace-per-PR).
- Policy-as-code exception workflow automated end to end from Backstage.
- AI: agentic PR remediation for Dependabot and policy findings (human-approved).
