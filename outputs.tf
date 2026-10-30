output "name" {
  description = "Name of the route table."
  value       = azapi_resource.this.name
}

output "resource_id" {
  description = "Resource ID of the route table, for the `routeTable` of the subnets that use it."
  value       = azapi_resource.this.id
}
