# Reads a user-assigned identity's isolation scope straight from Azure.
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
  }
}

variable "identity_id" {
  type = string
}

data "azapi_resource" "identity" {
  type                   = "Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30"
  resource_id            = var.identity_id
  response_export_values = ["properties.isolationScope"]
}

output "isolation_scope" {
  value = try(data.azapi_resource.identity.output.properties.isolationScope, null)
}
