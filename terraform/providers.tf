terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # Remote backend — bootstrap the storage account before running terraform init.
  # See README.md "Bootstrap Terraform Backend" section for the az CLI commands.
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-abdalhakim"
    storage_account_name = "tfstateabdalhakim"   # must be globally unique — change suffix if taken
    container_name       = "tfstate"
    key                  = "finalproject.tfstate"
  }
}

provider "azurerm" {
  features {}
}
