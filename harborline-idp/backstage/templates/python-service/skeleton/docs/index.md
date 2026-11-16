# ${{ values.name }}

${{ values.description }}

| | |
|---|---|
| Owner | `${{ values.owner }}` |
| Tier | `${{ values.tier }}` |
| Data classification | `${{ values.dataClassification }}` |

## Runbook

- Health: `GET /healthz/live` (process), `GET /healthz/ready` (dependencies).
- Dashboards: Grafana → *Harborline / Service golden signals* → service `${{ values.name }}`.
- Platform runbooks: <https://backstage.harborline.example/docs/default/component/harborline-idp/operations/runbooks/>
