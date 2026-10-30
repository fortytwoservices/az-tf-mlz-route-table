output "resource_id" {
  description = "Resource ID of the SQL Managed Instance subnet's route table."
  value       = module.route_table.resource_id
}

output "subnet_resource_id" {
  description = "Resource ID of the subnet for a SQL Managed Instance."
  value       = azapi_resource.sql_managed_instance_subnet.id
}
