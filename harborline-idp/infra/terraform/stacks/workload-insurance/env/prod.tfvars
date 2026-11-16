environment                  = "prod"
location                     = "canadacentral"
cost_center                  = "CC-2040"
subscription_id              = "00000000-0000-0000-0000-000000000030"
connectivity_subscription_id = "00000000-0000-0000-0000-000000000002"
management_subscription_id   = "00000000-0000-0000-0000-000000000001"

postgres = {
  sku_name             = "GP_Standard_D4ds_v5"
  storage_mb           = 131072
  high_availability    = true
  geo_redundant_backup = true
}

service_bus_capacity = 2

dba_group = {
  object_id      = "00000000-0000-0000-0000-00000000a010"
  principal_name = "grp-insurance-dba"
}
