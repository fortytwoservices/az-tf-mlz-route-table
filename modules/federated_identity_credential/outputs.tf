output "lock_dependency" {
  description = "Changes whenever the credential is created, replaced or changed. The parent passes it in its `lock_dependencies`: Azure applies the parent's lock to the credential too, and a `ReadOnly` lock also blocks updating it in place, which keeps its ID."
  value       = sha256(jsonencode([azapi_resource.this.id, azapi_resource.this.body]))
}

output "name" {
  description = "Name of the federated identity credential."
  value       = azapi_resource.this.name
}

output "resource_id" {
  description = "Resource ID of the federated identity credential."
  value       = azapi_resource.this.id
}
