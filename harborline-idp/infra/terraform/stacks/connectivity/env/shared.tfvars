location                     = "canadacentral"
cost_center                  = "CC-1001"
connectivity_subscription_id = "00000000-0000-0000-0000-000000000002"
management_subscription_id   = "00000000-0000-0000-0000-000000000001"
hub_address_space            = "10.0.0.0/22"
spoke_address_spaces         = {
  dev  = "10.10.0.0/16"
  stg  = "10.20.0.0/16"
  prod = "10.30.0.0/16"
}
enable_bastion      = true
extra_allowed_fqdns = []

# ADR-0010: Backstage (prod apps pool) reads the private AKS API servers of every environment.
east_west_rules = [
  {
    name                  = "adr-0010-backstage-to-aks-api"
    source_addresses      = ["10.30.4.0/22"]
    destination_addresses = ["10.10.0.0/24", "10.20.0.0/24"]
    destination_ports     = ["443"]
  },
]
