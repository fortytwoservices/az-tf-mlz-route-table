# The module with a subnet that uses its table, in one configuration, as a hub or a spoke has it: a
# replaced table must be created before the old one is deleted, which Azure refuses while the subnet uses
# it (InUseRouteTableCannotBeDeleted).
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
  }
}

variable "location" {
  type = string
}

variable "resource_group_id" {
  type = string
}

variable "route_table_name" {
  type = string
}

variable "suffix" {
  type = string
}

module "route_table" {
  source = "../../.."

  name      = var.route_table_name
  parent_id = var.resource_group_id
  location  = var.location
  routes = {
    default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" }
  }
  bgp_route_propagation_enabled = false
  lock                          = { kind = "CanNotDelete" }
}

resource "azapi_resource" "virtual_network" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = "vnet-mlz-rt-it-${var.suffix}"
  parent_id = var.resource_group_id
  location  = var.location
  body = {
    properties = {
      addressSpace = { addressPrefixes = ["10.100.8.0/24"] }
    }
  }

  response_export_values = []
}

resource "azapi_resource" "subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  name      = "snet-workload"
  parent_id = azapi_resource.virtual_network.id
  body = {
    properties = {
      addressPrefixes       = ["10.100.8.0/26"]
      defaultOutboundAccess = false
      routeTable            = { id = module.route_table.resource_id }
    }
  }

  response_export_values = []
}

output "resource_id" {
  value = module.route_table.resource_id
}

output "subnet_id" {
  value = azapi_resource.subnet.id
}
