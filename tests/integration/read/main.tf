# Reads a route table straight from Azure: its routes, settings, tags and the subnets that use it.
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
  }
}

variable "route_table_id" {
  type = string
}

data "azapi_resource" "route_table" {
  type                   = "Microsoft.Network/routeTables@2025-07-01"
  resource_id            = var.route_table_id
  response_export_values = ["properties", "tags"]
}

locals {
  properties = data.azapi_resource.route_table.output.properties
}

output "bgp_route_propagation_enabled" {
  value = !local.properties.disableBgpRoutePropagation
}

# In the module's input shape, by route name; Azure leaves out the address of every next hop but an
# appliance.
output "routes" {
  value = {
    for route in try(local.properties.routes, []) : route.name => {
      address_prefix         = route.properties.addressPrefix
      next_hop_type          = route.properties.nextHopType
      next_hop_in_ip_address = try(route.properties.nextHopIpAddress, null)
    }
  }
}

output "subnet_ids" {
  value = [for subnet in try(local.properties.subnets, []) : lower(subnet.id)]
}

output "tags" {
  value = try(data.azapi_resource.route_table.output.tags, null)
}
