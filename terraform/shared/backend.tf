terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-tfstate-shared"
    storage_account_name = "sttfstatesorcery01"
    container_name        = "tfstate"
    key                    = "shared.tfstate"
  }
}

provider "azurerm" {
  features {}
}
