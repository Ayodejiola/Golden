terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.40, < 5.0" }
  }
  # State account is pre-created by scripts/bootstrap-state.sh. Init with:
  #   terraform init -backend-config=env/shared.backend.hcl
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
  subscription_id     = var.management_subscription_id
  storage_use_azuread = true
}
