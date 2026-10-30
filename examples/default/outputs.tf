output "firewall_route_table_resource_id" {
  description = "Resource ID of the hub's AzureFirewallSubnet route table."
  value       = module.firewall_route_table.resource_id
}

output "spoke_route_table_resource_id" {
  description = "Resource ID of the spoke's route table."
  value       = module.spoke_route_table.resource_id
}
