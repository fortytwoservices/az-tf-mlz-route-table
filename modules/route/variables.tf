variable "address_prefix" {
  type        = string
  description = "The destination: a CIDR prefix in its canonical form (`10.1.0.0/16`, not `10.1.0.1/16`; IPv6 in lower case and compressed, as Terraform's `cidrsubnet` writes it), or a service tag such as `Storage.SwedenCentral`."
  nullable    = false

  # Azure refuses a prefix that is not the network's own address (InvalidCIDRNotation, sandbox 2026-10-29).
  validation {
    condition     = try(cidrsubnet(var.address_prefix, 0, 0) == var.address_prefix, false) || can(regex("^[A-Za-z][A-Za-z0-9.-]*$", var.address_prefix))
    error_message = "`address_prefix` must be a CIDR prefix in its canonical form (`10.1.0.0/16`, not `10.1.0.1/16`; IPv6 in lower case and compressed) or a service tag such as `Storage.SwedenCentral`."
  }
}

variable "name" {
  type        = string
  description = "Name of the route, unique in the table. Cannot be changed after creation."
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9._-]{0,78}[a-zA-Z0-9_])?$", var.name))
    error_message = "`name` must be 1 to 80 characters: letters, digits, periods, hyphens and underscores, starting with a letter or digit and ending with a letter, digit or underscore."
  }
}

variable "next_hop_type" {
  type        = string
  description = "`VirtualAppliance`, `VirtualNetworkGateway` (a VPN gateway only, and not for IPv6 prefixes), `VnetLocal`, `Internet` (Azure accepts only public destinations, `0.0.0.0/0` or a service tag) or `None` (drop)."
  nullable    = false

  validation {
    condition     = contains(["VirtualAppliance", "VirtualNetworkGateway", "VnetLocal", "Internet", "None"], var.next_hop_type)
    error_message = "`next_hop_type` must be `VirtualAppliance`, `VirtualNetworkGateway`, `VnetLocal`, `Internet` or `None`."
  }
  # Refused by Azure (InvalidNextHopType, sandbox 2026-10-29).
  validation {
    condition     = !(strcontains(var.address_prefix, ":") && var.next_hop_type == "VirtualNetworkGateway")
    error_message = "An IPv6 `address_prefix` cannot have the next hop type `VirtualNetworkGateway`."
  }
}

variable "parent_id" {
  type        = string
  description = "Resource ID of the route table that holds the route."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Network/routeTables", var.parent_id))
    error_message = "`parent_id` must be a route table resource ID."
  }
}

variable "next_hop_in_ip_address" {
  type        = string
  default     = null
  description = "(Optional) The appliance's private IP address, for example a firewall's: required for `VirtualAppliance` and refused for every other type. In the prefix's address family, written as Terraform's `cidrhost` writes it."

  validation {
    condition     = (var.next_hop_type == "VirtualAppliance") == (var.next_hop_in_ip_address != null)
    error_message = "`next_hop_in_ip_address` is required for `VirtualAppliance` and refused for every other next hop type."
  }
  validation {
    condition     = var.next_hop_in_ip_address == null ? true : try(cidrhost("${var.next_hop_in_ip_address}/${strcontains(var.next_hop_in_ip_address, ":") ? 128 : 32}", 0) == var.next_hop_in_ip_address, false)
    error_message = "`next_hop_in_ip_address` must be an IPv4 or IPv6 address, IPv6 in lower case and compressed (`fd00:db8::4`)."
  }
  # Refused by Azure (ResourceCannotContainAddressPrefixesFromDifferentAddressFamilies, sandbox 2026-10-29).
  validation {
    condition     = var.next_hop_in_ip_address == null || !strcontains(var.address_prefix, "/") ? true : strcontains(var.address_prefix, ":") == strcontains(var.next_hop_in_ip_address, ":")
    error_message = "`next_hop_in_ip_address` must be in the address family of `address_prefix` (IPv4 or IPv6)."
  }
}
