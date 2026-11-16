# Developer portal (Backstage)

**URL:** `https://backstage.harborline.example` (internal network / VPN). Sign in with Microsoft Entra ID.

## What's in it

| Area | Content | Source |
|---|---|---|
| Catalog | Components, APIs, systems, domains, resources, groups, users | `catalog-info.yaml` in every repo (GitHub discovery), Microsoft Graph for people |
| Create | Golden-path templates | `backstage/templates/*` |
| Docs | TechDocs built from each repo's `mkdocs.yml` (this site included) | local builder in the Backstage pod |
| Kubernetes | Live pods, deployments, errors per component across dev/stg/prod | Kubernetes plugin with workload identity (read-only) |
| APIs | OpenAPI specs rendered with try-it disabled for restricted systems | `API` entities |
| Search | Catalog + TechDocs | PostgreSQL search engine |

## Architecture

- New backend system (`packages/backend/src/index.ts`) and new frontend system with plugin discovery
  (`packages/app/src/App.tsx`).
- Runs in the **prod** platform cluster (namespace `backstage`, 2 replicas) via the `backstage` add-on; reaches
  dev/stg/prod API servers through an explicit firewall rule (ADR-0010).
- Auth: Entra ID; sign-in resolvers match users synced from Microsoft Graph.
- Authorization: `HarborlinePermissionPolicy` — read for all authenticated users; catalog deletion only for platform
  admins (entities are owned by Git).
- Secrets from Key Vault via CSI; database password under EXC-0001.

## Registering a component

Add `catalog-info.yaml` at the repo root (templates do this). Required: `owner`, `system`, `lifecycle`, `type`, and
annotations `github.com/project-slug`, `backstage.io/techdocs-ref`, `backstage.io/kubernetes-label-selector`.

## Local development

```bash
cd backstage
yarn install
GITHUB_TOKEN=<read-only PAT> yarn dev    # guest sign-in, in-memory SQLite
```
