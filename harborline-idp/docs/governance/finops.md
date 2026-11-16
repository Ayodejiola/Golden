# FinOps

## Principles

1. **Visibility first** — every resource is tagged with `cost-center` and `owner`; every namespace is labelled.
2. **Teams own their spend** — monthly chargeback: Azure resources by tag + shared cluster cost by namespace requests.
3. **Right-size by environment** — dev is cheap by default; prod is sized for SLOs, not peaks.
4. **Elastic by default** — autoscaling on every layer; nothing scales to zero that customers need.

## Environment cost levers

| Lever | dev | stg | prod |
|---|---|---|---|
| AKS tier | Free | Standard | Standard |
| Node pools | D4ds_v5, min 1/2 | D4/D8ds_v5, min 3 | D4/D8ds_v5, min 3, reserved instances (1-yr) for baseline |
| PostgreSQL | Burstable B2ms, no HA | GP D2ds, ZR HA | GP D4ds, ZR HA, geo backup |
| Service Bus | Premium 1 MU (PE requirement) | 1 MU | 2 MU |
| App Gateway | min 1 instance | min 1 | min 2 |
| Log ingestion | ContainerLogV2 basic tables candidate | standard | standard + 2 y audit retention |

## Shared cost allocation

Cluster cost (nodes + fixed fees) is split by each namespace's share of CPU and memory **requests** (not usage), which
rewards accurate sizing. AKS cost analysis add-on provides the namespace breakdown; the *Platform overview* dashboard
shows requests by namespace.

## Guardrails

- Budget alerts per subscription (50/80/100%) to owners and FinOps.
- Log Analytics daily cap available per workspace (`daily_quota_gb`).
- Quotas per tenant namespace prevent runaway scale.
- Quarterly review of reservations, idle resources (Azure Advisor) and over-requested workloads (VPA recommendations).
