location                      = "canadacentral"
cost_center                   = "CC-1001"
management_subscription_id    = "00000000-0000-0000-0000-000000000001"
connectivity_subscription_id  = "00000000-0000-0000-0000-000000000002"
landing_zone_subscription_ids = {
  dev  = "00000000-0000-0000-0000-000000000010"
  stg  = "00000000-0000-0000-0000-000000000020"
  prod = "00000000-0000-0000-0000-000000000030"
}
state_storage_account_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-tfstate-shared-cac-01/providers/Microsoft.Storage/storageAccounts/sthbltfstatecac01"
github_org               = "harborline"
github_repo              = "harborline-idp"
service_repositories     = []
