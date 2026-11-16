#!/usr/bin/env bash
# Creates the hardened Terraform state storage account (chicken-and-egg: state cannot hold its own storage).
# Run once by a Cloud Admin with PIM-elevated Owner on the management subscription. Idempotent.
#
#   scripts/bootstrap-state.sh <management-subscription-id> [location]
#
# Hardening: Entra-only auth (shared keys disabled), TLS 1.2, no public blob access, GZRS, versioning,
# soft delete (blobs + containers), infrastructure encryption, CanNotDelete lock, diagnostic-ready.
set -euo pipefail

SUB="${1:?usage: $0 <management-subscription-id> [location]}"
LOC="${2:-canadacentral}"
RG="rg-tfstate-shared-cac-01"
SA="sthbltfstatecac01"
CONTAINERS=(tfstate-shared tfstate-dev tfstate-stg tfstate-prod)

az account set --subscription "$SUB"

az group create --name "$RG" --location "$LOC" \
  --tags environment=shared workload=tfstate owner=platform-engineering cost-center=CC-1001 \
         data-classification=confidential managed-by=script repository=harborline/harborline-idp >/dev/null

if ! az storage account show -g "$RG" -n "$SA" >/dev/null 2>&1; then
  az storage account create -g "$RG" -n "$SA" -l "$LOC" \
    --sku Standard_GZRS --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --allow-shared-key-access false \
    --allow-cross-tenant-replication false \
    --require-infrastructure-encryption true \
    --default-action Deny --bypass AzureServices \
    --public-network-access Enabled >/dev/null
fi

az storage account blob-service-properties update -g "$RG" --account-name "$SA" \
  --enable-versioning true \
  --enable-delete-retention true --delete-retention-days 30 \
  --enable-container-delete-retention true --container-delete-retention-days 30 >/dev/null

for c in "${CONTAINERS[@]}"; do
  az storage container create --account-name "$SA" --name "$c" --auth-mode login >/dev/null
done

az lock create --name cannot-delete --lock-type CanNotDelete \
  --resource-group "$RG" --resource-name "$SA" --resource-type Microsoft.Storage/storageAccounts \
  --notes "Terraform state for all Harborline stacks" >/dev/null || true

cat <<EOF
State account ready: $SA (rg: $RG)
Next steps:
  1. Add a private endpoint for blob in the hub (after connectivity exists) and set --public-network-access Disabled.
  2. Allow your admin IP temporarily for the first bootstrap apply:
       az storage account network-rule add -g $RG --account-name $SA --ip-address <your-ip>
  3. cd infra/terraform/stacks/bootstrap && terraform init -backend-config=env/shared.backend.hcl
EOF
