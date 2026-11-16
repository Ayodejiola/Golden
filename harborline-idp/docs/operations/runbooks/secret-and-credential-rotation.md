# Secret and credential rotation

| | |
|---|---|
| **Alerts / trigger** | Scheduled (90 days) / suspected compromise |
| **Owner** | Secret owner (see inventory) |

Only a handful of secrets exist (see [secrets management](../../security/secrets-management.md)). Each rotates at least every 90 days and immediately on suspected compromise.

## Diagnose (read-only)

```bash
az keyvault secret list --vault-name kv-hbl-plat-prod-cac01 --query '[].{name:name, expires:attributes.expires}' -o table
```

## Mitigate

1. **Backstage DB password (EXC-0001):** set `backstage_db_password_rotation` in `platform/env/prod.tfvars` to the current timestamp → apply generates a new password and updates the server and Key Vault; the CSI driver syncs within 2 minutes; roll the Backstage pods via an annotation bump in Git.
2. **GitHub App keys (Argo CD, Backstage, GitOps bot):** generate a new private key in the GitHub App, store it in Key Vault / the org secret, verify, then delete the old key in GitHub.
3. **Entra client secret (Backstage):** add a new secret on the app registration, update Key Vault, verify sign-in, remove the old secret.
4. **Anthropic API key:** create a new workspace key with a spend limit, update the org secret, revoke the old key.
5. Compromise: revoke first, then rotate; check audit logs for use of the old credential; open a security incident.

## Verify

New secret versions in use; old credentials revoked; next rotation date recorded.

## Escalate

Page the next tier in [on-call](../oncall.md) if not mitigated within 30 minutes (SEV1) or 2 hours (SEV2). Record
actions in the incident timeline.
