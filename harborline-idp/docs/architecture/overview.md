# Architecture overview

The Harborline IDP is a layered platform: an **Azure Landing Zone** foundation, a **runtime** layer of private AKS
clusters, a **delivery** layer (GitHub Actions + Argo CD), a **developer experience** layer (Backstage, templates,
Claude + MCP), and **cross-cutting** security, observability and governance. Each layer is owned by a team, versioned
in this repository and exposed to product teams as self-service capabilities.

## System context (C4 level 1)

```mermaid
flowchart TB
  subgraph people[People]
    devs([Product engineers])
    plat([Platform / SRE / Security])
    cust([Customers & brokers])
  end
  idp[[Harborline IDP<br/>golden paths, runtime, guardrails]]
  gh[(GitHub Enterprise<br/>code, Actions, OIDC)]
  entra[(Microsoft Entra ID<br/>workforce + workload identity)]
  azure[(Azure<br/>Canada Central / Canada East)]
  sig[(Sigstore<br/>Fulcio + Rekor)]
  llm[(Claude<br/>via Claude Code)]
  devs -->|scaffold, deploy, observe| idp
  plat -->|operate, govern| idp
  cust -->|HTTPS| idp
  idp --> gh
  idp --> entra
  idp --> azure
  idp --> sig
  devs -. AI-assisted, guarded .-> llm
  llm -. MCP, read-only .-> idp
```

## Containers (C4 level 2)

```mermaid
flowchart LR
  subgraph dx[Developer experience]
    bs[Backstage portal<br/>catalog · templates · TechDocs]
    mcp[platform-catalog MCP]
    cc[Claude Code<br/>hooks + permissions]
  end
  subgraph delivery[Delivery]
    gha[GitHub Actions<br/>trusted builder]
    acr[(ACR Premium)]
    repo[(harborline-idp<br/>gitops/)]
    argo[Argo CD<br/>per cluster]
  end
  subgraph runtime[Runtime - per environment spoke]
    agw[App Gateway WAF v2]
    nginx[Internal NGINX<br/>app routing]
    aks[AKS private<br/>Cilium · WI · Kyverno]
    pg[(PostgreSQL Flexible)]
    sb[[Service Bus Premium]]
    kv[(Key Vault)]
  end
  subgraph obs[Observability - management]
    otel[OTel Collector]
    ai[(Application Insights)]
    prom[(Managed Prometheus)]
    graf[Managed Grafana]
  end
  bs -->|PRs| repo
  gha -->|signed images| acr
  gha -->|digest PRs| repo
  argo -->|pull| repo
  argo --> aks
  aks -->|pull by digest| acr
  agw --> nginx --> aks
  aks --> pg & sb & kv
  aks --> otel --> ai
  otel --> prom --> graf
  cc --> mcp --> repo
```

## Deployment topology

```mermaid
flowchart TB
  subgraph mg[Management groups]
    root[hbl] --> platform[Platform] & lz[Landing zones] & sandbox[Sandbox]
    platform --> mgmt[Management] & conn[Connectivity] & ident[Identity]
    lz --> corp[Corp]
  end
  subgraph subs[Subscriptions]
    smgmt[sub-mgmt: Log Analytics, AMW, Grafana, ACR, CI identities, TF state]
    sconn[sub-connectivity: hub VNet, Firewall Premium, Bastion, Private DNS]
    sdev[sub-lz-dev: spoke 10.10/16, AKS, KV, AGW, PG, SB]
    sstg[sub-lz-stg: spoke 10.20/16]
    sprod[sub-lz-prod: spoke 10.30/16 + Backstage]
  end
  mgmt --- smgmt
  conn --- sconn
  corp --- sdev & sstg & sprod
  sdev & sstg & sprod <-->|peering, UDR 0/0 → firewall| sconn
```

## Request path (customer quote)

```mermaid
sequenceDiagram
  autonumber
  actor U as Customer
  participant W as App Gateway WAF
  participant N as NGINX (internal)
  participant API as policy-api
  participant E as Entra ID
  participant DB as PostgreSQL
  participant SB as Service Bus
  participant WK as claims-worker
  U->>E: Sign in (auth code + PKCE)
  U->>W: POST /api/v1/claims (Bearer)
  W->>W: DRS 2.1, bot, geo, rate limit
  W->>N: HTTPS (re-encrypted)
  N->>API: HTTP within pod network (NetworkPolicy)
  API->>API: Validate JWT (iss, aud, tid, scp/roles)
  API->>E: Workload identity token (DB scope)
  API->>DB: INSERT claim + outbox (one transaction)
  API-->>U: 201 Created
  API->>SB: Outbox relay publishes claim.submitted
  SB->>WK: claims/triage subscription
  WK->>DB: Idempotent triage update
```

## Key properties

| Property | How |
|---|---|
| No public data plane | Private endpoints for every PaaS service; private AKS API; only the WAF has a public IP |
| No long-lived secrets | Workload identity for pods, OIDC for CI, Entra auth for PostgreSQL and Service Bus |
| Everything as code | Terraform, Helm, Kustomize, policies, dashboards, alerts, SLOs, docs |
| Pull-based delivery | Argo CD in each cluster; CI never holds cluster credentials |
| Verifiable supply chain | Sigstore signatures + SLSA provenance verified at admission |
| Paved road | One chart, one pipeline, one portal; deviations require an exception record |

Rendered SVGs of every diagram (for slides and reviews) live in `docs/architecture/diagrams/` (`make diagrams`).

Deep dives: [Landing zone](landing-zone.md) · [Network](network.md) · [Identity](identity-and-access.md) ·
[AKS](aks-platform.md) · [Data & messaging](data-and-messaging.md) · [Observability](observability.md) ·
[GitOps & delivery](gitops-and-delivery.md) · [Well-Architected](well-architected.md)
