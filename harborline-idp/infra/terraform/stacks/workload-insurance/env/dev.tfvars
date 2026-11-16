environment                  = "dev"
location                     = "canadacentral"
cost_center                  = "CC-2040"
subscription_id              = "00000000-0000-0000-0000-000000000010"
connectivity_subscription_id = "00000000-0000-0000-0000-000000000002"
management_subscription_id   = "00000000-0000-0000-0000-000000000001"

postgres = {
  sku_name             = "B_Standard_B2ms"
  storage_mb           = 32768
  high_availability    = false
  geo_redundant_backup = false
}

service_bus_capacity = 1

dba_group = {
  object_id      = "00000000-0000-0000-0000-00000000a010"
  principal_name = "grp-insurance-dba"
}
