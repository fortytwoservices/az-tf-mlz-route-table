# Subscription from ARM_SUBSCRIPTION_ID or the Azure CLI; credentials from the Azure CLI or OIDC.
provider "azapi" {}

locals {
  location = "swedencentral"
  tags     = { example = "sql_managed_instance_subnet" }
}

data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-11-01"
  name      = "rg-mlz-rt-sqlmi-${random_string.suffix.result}"
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  location  = local.location

  response_export_values = []
  tags                   = local.tags
}

# A SQL Managed Instance adds its own routes to its subnet's table when it is created (its network intent
# policy), and Azure refuses any table write without them: the table keeps Azure's routes, and its own
# routes are child resources. Here a spoke's default route to a hub firewall's address.
module "route_table" {
  source = "../../"

  name                         = "rt-sqlmi-mlz-${random_string.suffix.result}"
  parent_id                    = azapi_resource.resource_group.id
  location                     = local.location
  azure_managed_routes_enabled = true
  routes = {
    default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" }
  }
  bgp_route_propagation_enabled = false
  tags                          = local.tags
}

# The instance adds rules of its own to its subnet's NSG too, and Azure refuses any NSG write without them
# (ConflictWithNetworkIntentPolicy, SQL MI sandbox 2026-10-30). As for the table: an empty rule list, and
# the live rules sent on every write, from the NSG's creation.
resource "azapi_resource" "network_security_group" {
  type      = "Microsoft.Network/networkSecurityGroups@2024-05-01"
  name      = "nsg-sqlmi-mlz-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  body = {
    properties = {
      securityRules = []
    }
  }
  ignore_body_changes = ["properties.securityRules"]

  response_export_values = []
  tags                   = local.tags
}

resource "azapi_resource" "virtual_network" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = "vnet-sqlmi-mlz-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  body = {
    properties = {
      addressSpace = { addressPrefixes = ["10.90.0.0/24"] }
    }
  }

  response_export_values = []
  tags                   = local.tags
}

# The subnet a SQL Managed Instance is deployed into: delegated, with its network security group and route
# table, which the instance's network intent policy then fills.
resource "azapi_resource" "sql_managed_instance_subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  name      = "snet-sqlmi"
  parent_id = azapi_resource.virtual_network.id
  body = {
    properties = {
      addressPrefixes      = ["10.90.0.0/27"]
      networkSecurityGroup = { id = azapi_resource.network_security_group.id }
      routeTable           = { id = module.route_table.resource_id }
      delegations = [{
        name       = "sql-managed-instances"
        properties = { serviceName = "Microsoft.Sql/managedInstances" }
      }]
    }
  }

  response_export_values = []
}
