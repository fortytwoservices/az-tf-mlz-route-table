output "name" {
  description = "Name of the route table."
  value       = azapi_resource.this.name
}

output "resource_id" {
  description = "Resource ID of the route table, for the `routeTable` of the subnets that use it. With Azure-managed routes, a subnet that uses it is written only after the table's routes, so it moves to a replaced table once the new table's routes exist (the old table's routes may be deleted shortly before: see `azure_managed_routes_enabled`)."
  value       = azapi_resource.this.id

  # With Azure-managed routes the routes are child resources, written after the table.
  depends_on = [module.route]
}
