terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    random = {
      source = "hashicorp/random"
    }
  }

  # === Remote state backend (YOUR values) ===
  backend "azurerm" {
    resource_group_name  = "rg-MyLab-tf"
    storage_account_name = "mystorage192315"
    container_name       = "containerstate"
    key                  = "mylab-dev.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = "ce5cd128-0aae-46b2-93aa-ab8fc8777681"
  tenant_id       = "aed12201-0cd2-4e26-8816-167edf561845"
}
