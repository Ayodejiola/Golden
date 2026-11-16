# Personas and journeys

## Personas

| Persona | Goals | Pain today | Platform answer |
|---|---|---|---|
| **Priya — product engineer** (Insurance Digital) | Ship features weekly, understand prod behaviour | Tickets for infra, unclear security rules | Templates, golden chart, dashboards, AI with context |
| **Marc — tech lead** | Predictable delivery, compliant services | Audit questions, inconsistent pipelines | Scorecards, evidence by default, promotion workflow |
| **Aisha — SRE** | Reliable services, quiet on-call | Missing runbooks, noisy alerts | SLO-as-code, runbook links, standard telemetry |
| **Jean — security architect** | Provable controls, low risk | Shadow infra, secrets sprawl | Policy as code, workload identity, signed supply chain |
| **Lena — platform engineer** | Scale the platform, few snowflakes | Bespoke requests | Self-service, exceptions process, GitOps |

## Journey: idea → production (target < 1 week for a new service)

| Step | Experience | Time |
|---|---|---|
| 1. Onboard team | Backstage → Tenant onboarding → PR approved | < 1 day |
| 2. Create service | Backstage → Python API service | 5 min |
| 3. First deploy to dev | Merge → CI → GitOps PR auto-merge → Argo CD | < 15 min |
| 4. Database/messaging | PR to `workload-<team>` stack from module examples | < 1 day |
| 5. Observe | Golden-signals dashboard auto-populates; SLO PR | < 1 hour |
| 6. Promote | `promote.yml` dev → stg → prod with approvals | minutes + review |

## Journey: on-call alert → mitigation

Alert (runbook link) → `/incident-assist <alert>` checklist → dashboards/traces → rollback PR or runbook action →
post-incident review → backlog item for platform or team.
