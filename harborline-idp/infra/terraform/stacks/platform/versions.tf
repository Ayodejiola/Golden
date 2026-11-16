terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.40, < 5.0" }
    azapi   = { source = "Azure/azapi", version = ">= 2.0, < 3.0" }
    random  = { source = "hashicorp/random", version = ">= 3.6, < 4.0" }
  }
  backend "azurerm" {}
}

# Application landing zone subscription for this environment.
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
  subscription_id     = var.subscription_id
  storage_use_azuread = true
}

provider "azurerm" {
  alias = "hub"
  features {}
  subscription_id     = var.connectivity_subscription_id
  storage_use_azuread = true
}

provider "azurerm" {
  alias = "management"
  features {}
  subscription_id     = var.management_subscription_id
  storage_use_azuread = true
}

provider "azapi" {
  subscription_id = var.subscription_id
}
