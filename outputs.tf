output "client_id" {
  description = "Client (application) ID of the user-assigned identity."
  value       = azapi_resource.this.output.properties.clientId
}

output "federated_identity_credential_resource_ids" {
  description = "Resource IDs of the federated identity credentials, by credential name."
  value       = { for name, credential in module.federated_identity_credential : name => credential.resource_id }
}

output "name" {
  description = "Name of the user-assigned identity."
  value       = azapi_resource.this.name
}

output "principal_id" {
  description = "Object (principal) ID of the user-assigned identity's service principal."
  value       = azapi_resource.this.output.properties.principalId
}

output "resource_id" {
  description = "Resource ID of the user-assigned identity."
  value       = azapi_resource.this.id
}

output "tenant_id" {
  description = "Tenant ID of the user-assigned identity."
  value       = azapi_resource.this.output.properties.tenantId
}
