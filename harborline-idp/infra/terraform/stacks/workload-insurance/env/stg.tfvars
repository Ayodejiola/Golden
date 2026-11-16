environment                  = "stg"
location                     = "canadacentral"
cost_center                  = "CC-2040"
subscription_id              = "00000000-0000-0000-0000-000000000020"
connectivity_subscription_id = "00000000-0000-0000-0000-000000000002"
management_subscription_id   = "00000000-0000-0000-0000-000000000001"

postgres = {
  sku_name             = "GP_Standard_D2ds_v5"
  storage_mb           = 65536
  high_availability    = true
  geo_redundant_backup = false
}

service_bus_capacity = 1

dba_group = {
  object_id      = "00000000-0000-0000-0000-00000000a010"
  principal_name = "grp-insurance-dba"
}
