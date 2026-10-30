output "lock_dependency" {
  description = "Changes whenever the route is created, replaced or written: its ID, API version (`type`, a new one writes the route) and body. The table passes it in its `lock_dependencies`: Azure applies the table's lock to the route too, so a `CanNotDelete` lock blocks deleting it and a `ReadOnly` lock also blocks changing it."
  value       = sha256(jsonencode([azapi_resource.this.id, azapi_resource.this.type, azapi_resource.this.body]))
}

output "name" {
  description = "Name of the route."
  value       = azapi_resource.this.name
}

output "resource_id" {
  description = "Resource ID of the route."
  value       = azapi_resource.this.id
}
