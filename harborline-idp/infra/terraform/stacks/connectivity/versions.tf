terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.40, < 5.0" }
  }
  backend "azurerm" {}
}

provider "azurerm" {
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
