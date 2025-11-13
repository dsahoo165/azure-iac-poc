terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  
  # Skip provider registration as we're using free tier
  skip_provider_registration = true
}

# Resource Group
resource "azurerm_resource_group" "appgw_lab" {
  name     = var.resource_group_name
  location = var.location
}
