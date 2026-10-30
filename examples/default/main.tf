# Subscription from ARM_SUBSCRIPTION_ID or the Azure CLI; credentials from the Azure CLI or OIDC.
provider "azapi" {}

locals {
  location = "swedencentral"
  tags     = { example = "default" }
  # Azure gives a firewall the fifth address of AzureFirewallSubnet; no firewall is deployed here.
  firewall_subnet_address_prefix = "10.100.0.0/26"
  firewall_private_ip_address    = cidrhost(local.firewall_subnet_address_prefix, 4)
  # What a connectivity composition publishes as `spoke_default_routes`, for subscription vending.
  spoke_default_routes = {
    default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = local.firewall_private_ip_address }
  }
}

data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-11-01"
  name      = "rg-mlz-rt-${random_string.suffix.result}"
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  location  = local.location

  response_export_values = []
  tags                   = local.tags
}

# The hub's AzureFirewallSubnet: the Internet directly, and another region's hub through that hub's
# firewall (Microsoft Learn, "Use Azure Firewall to route a multi-hub and spoke topology"). Gateway route
# propagation stays on, so the firewall learns on-premises routes.
module "firewall_route_table" {
  source = "../../"

  name      = "rt-afw-mlz-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  routes = {
    internet       = { name = "internet", address_prefix = "0.0.0.0/0", next_hop_type = "Internet" }
    hub_westeurope = { name = "hub-westeurope", address_prefix = "10.101.0.0/16", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.101.0.4" }
  }
  tags = local.tags
}

# A spoke: everything through the hub's firewall, and no BGP-learned routes that would bypass it.
module "spoke_route_table" {
  source = "../../"

  name                          = "rt-spoke-mlz-${random_string.suffix.result}"
  parent_id                     = azapi_resource.resource_group.id
  location                      = local.location
  routes                        = local.spoke_default_routes
  bgp_route_propagation_enabled = false
  tags                          = local.tags
}

resource "azapi_resource" "hub_virtual_network" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = "vnet-hub-mlz-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  body = {
    properties = {
      addressSpace = { addressPrefixes = ["10.100.0.0/22"] }
    }
  }

  response_export_values = []
  tags                   = local.tags
}

# Subnets associate themselves with a route table; the table has no list of subnets to write.
resource "azapi_resource" "firewall_subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  name      = "AzureFirewallSubnet"
  parent_id = azapi_resource.hub_virtual_network.id
  body = {
    properties = {
      addressPrefixes = [local.firewall_subnet_address_prefix]
      routeTable      = { id = module.firewall_route_table.resource_id }
    }
  }

  response_export_values = []
}

resource "azapi_resource" "spoke_virtual_network" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = "vnet-spoke-mlz-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  body = {
    properties = {
      addressSpace = { addressPrefixes = ["10.100.8.0/24"] }
    }
  }

  response_export_values = []
  tags                   = local.tags
}

resource "azapi_resource" "workload_subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  name      = "snet-workload"
  parent_id = azapi_resource.spoke_virtual_network.id
  body = {
    properties = {
      addressPrefixes       = ["10.100.8.0/26"]
      defaultOutboundAccess = false
      routeTable            = { id = module.spoke_route_table.resource_id }
    }
  }

  response_export_values = []
}
