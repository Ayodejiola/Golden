environment                  = "stg"
location                     = "canadacentral"
cost_center                  = "CC-1001"
subscription_id              = "00000000-0000-0000-0000-000000000020"
connectivity_subscription_id = "00000000-0000-0000-0000-000000000002"
management_subscription_id   = "00000000-0000-0000-0000-000000000001"
spoke_address_space          = "10.20.0.0/16"

kubernetes_version = "1.35"
aks_sku_tier       = "Standard"

system_pool = {
  vm_size   = "Standard_D4ds_v5"
  min_count = 3
  max_count = 4
}

user_pools = {
  apps = {
    vm_size   = "Standard_D8ds_v5"
    min_count = 3
    max_count = 9
  }
}

groups = {
  platform_admins      = "00000000-0000-0000-0000-00000000a001"
  platform_admins_name = "grp-platform-admins"
  all_engineers        = "00000000-0000-0000-0000-00000000a002"
}

public_sites = {
  portal = {
    host_name        = "portal.stg.harborline.example"
    certificate_name = "portal-tls"
  }
}

github_business_id = null
