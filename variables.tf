variable "location" {
  type        = string
  description = "Azure region of the route table, for example `swedencentral`. Only subnets of virtual networks in the same region and subscription can use it (Microsoft Learn)."
  nullable    = false
}

variable "name" {
  type        = string
  description = "Name of the route table. A replacement (a change of `name`, `parent_id` or `location`) creates the new table before the old one is deleted, because Azure deletes no route table a subnet uses: subnets in the same configuration move to the new table first. A change of `location` alone therefore also needs a new `name`."
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9._-]{0,78}[a-zA-Z0-9_])?$", var.name))
    error_message = "`name` must be 1 to 80 characters: letters, digits, periods, hyphens and underscores, starting with a letter or digit and ending with a letter, digit or underscore."
  }
}

variable "parent_id" {
  type        = string
  description = "Resource ID of the resource group the route table is created in."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a resource group resource ID."
  }
}

variable "bgp_route_propagation_enabled" {
  type        = bool
  default     = true
  description = "(Optional) Whether the subnets using the table also get the routes a virtual network gateway learns over BGP (sent as `disableBgpRoutePropagation`, its opposite). Defaults to `true`, Azure's default, which `GatewaySubnet` must keep. Spokes behind a hub firewall set `false`, so that on-premises prefixes do not bypass the firewall (Microsoft Learn, \"Use Azure Firewall to route a multi-hub and spoke topology\")."
  nullable    = false
}

variable "routes" {
  type = map(object({
    name                   = string
    address_prefix         = string
    next_hop_type          = string
    next_hop_in_ip_address = optional(string)
  }))
  default     = {}
  description = <<DESCRIPTION
(Optional) The table's routes, keyed by any stable name, in the shape of `Azure/avm-ptn-alz-sub-vending/azure`'s route table `routes` and of the connectivity compositions' `spoke_default_routes`, which can be passed straight in. Every route is written in the table's body: removing one removes it from Azure.

- `name` - Name of the route, unique in the table: 1 to 80 characters, letters, digits, periods, hyphens and underscores, starting with a letter or digit and ending with a letter, digit or underscore.
- `address_prefix` - The destination: a CIDR prefix in its canonical form (`10.1.0.0/16`, not `10.1.0.1/16`; IPv6 lower case and compressed, as Terraform's `cidrsubnet` writes it), or a service tag such as `Storage.SwedenCentral` (at most 25 service-tag routes per table).
- `next_hop_type` - `VirtualAppliance`, `VirtualNetworkGateway` (a VPN gateway only, and not for IPv6 prefixes), `VnetLocal`, `Internet` (Azure accepts only public destinations, `0.0.0.0/0` or a service tag) or `None` (drop).
- `next_hop_in_ip_address` - (Optional) The appliance's private IP address, for example a firewall's: required for `VirtualAppliance` and refused for every other type. In the prefix's address family, written as Terraform's `cidrhost` writes it.

A table holds at most 400 routes.
DESCRIPTION
  nullable    = false

  validation {
    condition     = length(var.routes) <= 400
    error_message = "A route table holds at most 400 routes (Microsoft Learn)."
  }
  validation {
    condition     = alltrue([for route in values(var.routes) : can(regex("^[a-zA-Z0-9]([a-zA-Z0-9._-]{0,78}[a-zA-Z0-9_])?$", route.name))])
    error_message = "Each `routes[*].name` must be 1 to 80 characters: letters, digits, periods, hyphens and underscores, starting with a letter or digit and ending with a letter, digit or underscore."
  }
  validation {
    condition     = length(distinct([for route in values(var.routes) : lower(route.name)])) == length(var.routes)
    error_message = "Each `routes[*].name` must be unique in the table (names are not case-sensitive)."
  }
  validation {
    condition     = alltrue([for route in values(var.routes) : contains(["VirtualAppliance", "VirtualNetworkGateway", "VnetLocal", "Internet", "None"], route.next_hop_type)])
    error_message = "Each `routes[*].next_hop_type` must be `VirtualAppliance`, `VirtualNetworkGateway`, `VnetLocal`, `Internet` or `None`."
  }
  validation {
    condition     = alltrue([for route in values(var.routes) : (route.next_hop_type == "VirtualAppliance") == (route.next_hop_in_ip_address != null)])
    error_message = "`routes[*].next_hop_in_ip_address` is required for `VirtualAppliance` and refused for every other next hop type."
  }
  validation {
    condition = alltrue([
      for route in values(var.routes) : route.next_hop_in_ip_address == null ? true :
      try(cidrhost("${route.next_hop_in_ip_address}/${strcontains(route.next_hop_in_ip_address, ":") ? 128 : 32}", 0) == route.next_hop_in_ip_address, false)
    ])
    error_message = "Each `routes[*].next_hop_in_ip_address` must be an IPv4 or IPv6 address, IPv6 in lower case and compressed (`fd00:db8::4`)."
  }
  # Azure refuses a prefix that is not the network's own address (InvalidCIDRNotation, sandbox 2026-10-29).
  validation {
    condition = alltrue([
      for route in values(var.routes) :
      try(cidrsubnet(route.address_prefix, 0, 0) == route.address_prefix, false) || can(regex("^[A-Za-z][A-Za-z0-9.-]*$", route.address_prefix))
    ])
    error_message = "Each `routes[*].address_prefix` must be a CIDR prefix in its canonical form (`10.1.0.0/16`, not `10.1.0.1/16`; IPv6 in lower case and compressed) or a service tag such as `Storage.SwedenCentral`."
  }
  validation {
    condition     = length([for route in values(var.routes) : route if !strcontains(route.address_prefix, "/")]) <= 25
    error_message = "A route table holds at most 25 routes with a service tag as `address_prefix` (Microsoft Learn)."
  }
  # Both refused by Azure (sandbox, 2026-10-29): ResourceCannotContainAddressPrefixesFromDifferentAddressFamilies
  # and InvalidNextHopType.
  validation {
    condition = alltrue([
      for route in values(var.routes) : route.next_hop_in_ip_address == null || !strcontains(route.address_prefix, "/") ? true :
      strcontains(route.address_prefix, ":") == strcontains(route.next_hop_in_ip_address, ":")
    ])
    error_message = "A route's `next_hop_in_ip_address` must be in the address family of its `address_prefix` (IPv4 or IPv6)."
  }
  validation {
    condition     = alltrue([for route in values(var.routes) : !(strcontains(route.address_prefix, ":") && route.next_hop_type == "VirtualNetworkGateway")])
    error_message = "An IPv6 `address_prefix` cannot have the next hop type `VirtualNetworkGateway`."
  }
}
