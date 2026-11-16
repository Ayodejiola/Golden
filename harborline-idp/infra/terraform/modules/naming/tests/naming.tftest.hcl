variables {
  workload            = "plat"
  environment         = "prod"
  location            = "canadacentral"
  owner               = "platform-engineering"
  cost_center         = "CC-1001"
  data_classification = "confidential"
}

run "standard_names" {
  command = plan

  assert {
    condition     = output.names.aks == "aks-plat-prod-cac-01"
    error_message = "AKS name does not follow the convention."
  }

  assert {
    condition     = output.names.resource_group == "rg-plat-prod-cac-01"
    error_message = "Resource group name does not follow the convention."
  }
}

run "constrained_names_respect_limits" {
  command = plan

  assert {
    condition     = length(output.names.key_vault) <= 24 && can(regex("^[a-zA-Z][a-zA-Z0-9-]+$", output.names.key_vault))
    error_message = "Key Vault name violates Azure limits."
  }

  assert {
    condition     = length(output.names.storage_account) <= 24 && can(regex("^[a-z0-9]+$", output.names.storage_account))
    error_message = "Storage account name violates Azure limits."
  }

  assert {
    condition     = can(regex("^[a-z0-9]{5,50}$", output.names.container_registry))
    error_message = "ACR name violates Azure limits."
  }
}

run "mandatory_tags_present" {
  command = plan

  assert {
    condition = alltrue([for k in ["environment", "owner", "cost-center", "data-classification", "managed-by"] :
    contains(keys(output.tags), k)])
    error_message = "Mandatory tags missing."
  }
}

run "rejects_unapproved_region" {
  command = plan

  variables {
    location = "westeurope"
  }

  expect_failures = [var.location]
}
