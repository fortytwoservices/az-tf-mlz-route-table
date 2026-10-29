# Subscription from ARM_SUBSCRIPTION_ID or the Azure CLI; credentials from the Azure CLI or OIDC.
provider "azapi" {}

locals {
  location = "norwayeast"
  tags     = { example = "default" }
}

data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-11-01"
  name      = "rg-mlz-template-${random_string.suffix.result}"
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  location  = local.location

  response_export_values = []
  tags                   = local.tags
}

module "user_assigned_identity" {
  source = "../../"

  name      = "id-mlz-template-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  federated_identity_credentials = {
    github-main = {
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:example-org/example-repo:ref:refs/heads/main"
    }
    github-pull-request = {
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:example-org/example-repo:pull_request"
    }
  }
  tags = local.tags
}
