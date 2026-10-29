# A resource group and a user-assigned identity for one integration test run.
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-11-01"
  name      = "rg-mlz-it-${random_string.suffix.result}"
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  location  = "norwayeast"
}

resource "azapi_resource" "identity" {
  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30"
  name      = "id-mlz-it-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = azapi_resource.resource_group.location
}

output "identity_id" {
  value = azapi_resource.identity.id
}
