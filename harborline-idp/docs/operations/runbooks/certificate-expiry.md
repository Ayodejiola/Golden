# TLS certificate expiry

| | |
|---|---|
| **Alerts / trigger** | Key Vault `CertificateNearExpiry` event / WAF backend health warnings |
| **Owner** | Platform primary |

Public (`portal-tls`) and internal (`wildcard-internal`) certificates live in the platform Key Vault and are consumed by App Gateway and app routing NGINX by versionless reference, so renewals are picked up automatically.

## Diagnose (read-only)

```bash
az keyvault certificate list --vault-name kv-hbl-plat-<env>-cac01 --query '[].{name:name, expires:attributes.expires}' -o table
az network application-gateway show-backend-health -g rg-plat-<env>-cac-01 -n agw-plat-<env>-cac-01 -o table
```

## Mitigate

1. If issued by an integrated CA, trigger renewal in Key Vault with the existing certificate policy.
2. Otherwise import the renewed PFX (`az keyvault certificate import`) as a new version; App Gateway picks it up within hours, CSI rotation within 2 minutes. Re-apply the platform stack to force App Gateway refresh if urgent.
3. Verify the chain: `openssl s_client -connect portal.harborline.example:443 -servername portal.harborline.example`.

## Verify

New expiry served on public and internal endpoints; backend health Healthy.

## Escalate

Page the next tier in [on-call](../oncall.md) if not mitigated within 30 minutes (SEV1) or 2 hours (SEV2). Record
actions in the incident timeline.
