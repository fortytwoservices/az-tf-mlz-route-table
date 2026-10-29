# A resource group for one integration test run, and the identity running the test.
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

output "location" {
  value = azapi_resource.resource_group.location
}

output "object_id" {
  value = data.azapi_client_config.current.object_id
}

output "resource_group_id" {
  value = azapi_resource.resource_group.id
}

output "suffix" {
  value = random_string.suffix.result
}
