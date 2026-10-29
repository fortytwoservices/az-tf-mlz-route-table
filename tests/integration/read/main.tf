# Reads federated identity credentials straight from Azure; fails if one is gone.
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
  }
}

variable "credential_ids" {
  type = map(string)
}

data "azapi_resource" "credential" {
  for_each = var.credential_ids

  type                   = "Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2024-11-30"
  resource_id            = each.value
  response_export_values = ["properties.subject"]
}

output "subjects" {
  value = { for name, credential in data.azapi_resource.credential : name => credential.output.properties.subject }
}
