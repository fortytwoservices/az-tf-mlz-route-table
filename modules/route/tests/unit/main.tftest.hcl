mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/routeTables/rt-test/routes/default"
    }
  }
}

variables {
  name           = "default"
  parent_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/routeTables/rt-test"
  address_prefix = "0.0.0.0/0"
  next_hop_type  = "Internet"
}

run "defaults" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/routeTables/routes@2025-07-01" && azapi_resource.this.name == var.name && azapi_resource.this.parent_id == var.parent_id
    error_message = "The route should use the default resource type, name and parent_id."
  }
  assert {
    condition     = jsonencode(azapi_resource.this.body) == jsonencode({ properties = { addressPrefix = "0.0.0.0/0", nextHopIpAddress = null, nextHopType = "Internet" } })
    error_message = "The body should send the prefix, the next hop type and a null address."
  }
  assert {
    condition     = jsonencode(azapi_resource.this.locks) == jsonencode([var.parent_id])
    error_message = "Writes should lock the table's ID, so a table's routes are written one at a time."
  }
  assert {
    condition     = azapi_resource.this.ignore_body_changes == null && azapi_resource.this.retry == null && azapi_resource.this.timeouts == null
    error_message = "ignore_body_changes, retry and timeouts should be unset by default."
  }
  assert {
    condition     = output.resource_id == azapi_resource.this.id && output.name == var.name && output.lock_dependency == sha256(jsonencode([azapi_resource.this.id, azapi_resource.this.body]))
    error_message = "resource_id, name and a body-aware lock_dependency should be output."
  }
}

run "appliance" {
  command = apply

  variables {
    address_prefix         = "fd00:db8::/48"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "fd00:db8:1::4"
  }

  assert {
    condition     = jsonencode(azapi_resource.this.body) == jsonencode({ properties = { addressPrefix = "fd00:db8::/48", nextHopIpAddress = "fd00:db8:1::4", nextHopType = "VirtualAppliance" } })
    error_message = "An appliance route should send its address."
  }
}

run "azapi_settings" {
  command = apply

  variables {
    resource_types      = { network_route_tables_routes = "Microsoft.Network/routeTables/routes@2024-05-01" }
    ignore_body_changes = { network_route_tables_routes = ["properties.nextHopType"] }
    retry               = { error_message_regex = ["AnotherOperationInProgress"] }
    timeouts            = { create = "30m", delete = "30m" }
  }

  # ignore_body_changes is write-only, so its wiring is reviewed (§ 10).
  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/routeTables/routes@2024-05-01"
    error_message = "resource_types should reach the route."
  }
  assert {
    condition     = azapi_resource.this.retry.error_message_regex == tolist(["AnotherOperationInProgress"]) && azapi_resource.this.timeouts.create == "30m" && azapi_resource.this.timeouts.delete == "30m"
    error_message = "retry and timeouts should reach the route."
  }
}

run "invalid_name" {
  command = plan

  variables {
    name = "default-"
  }

  expect_failures = [var.name]
}

run "invalid_parent_id" {
  command = plan

  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  }

  expect_failures = [var.parent_id]
}

run "host_bits_in_address_prefix" {
  command = plan

  variables {
    address_prefix = "10.100.8.1/24"
  }

  expect_failures = [var.address_prefix]
}

run "invalid_next_hop_type" {
  command = plan

  variables {
    next_hop_type = "VirtualNetworkPeering"
  }

  expect_failures = [var.next_hop_type]
}

run "ipv6_to_gateway" {
  command = plan

  variables {
    address_prefix = "fd00:db8::/48"
    next_hop_type  = "VirtualNetworkGateway"
  }

  expect_failures = [var.next_hop_type]
}

run "appliance_without_ip_address" {
  command = plan

  variables {
    next_hop_type = "VirtualAppliance"
  }

  expect_failures = [var.next_hop_in_ip_address]
}

run "ip_address_without_appliance" {
  command = plan

  variables {
    next_hop_in_ip_address = "10.100.0.4"
  }

  expect_failures = [var.next_hop_in_ip_address]
}

run "uncompressed_ipv6_address" {
  command = plan

  variables {
    address_prefix         = "fd00:db8::/48"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "FD00:DB8:1:0:0:0:0:4"
  }

  expect_failures = [var.next_hop_in_ip_address]
}

run "mixed_address_families" {
  command = plan

  variables {
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "fd00:db8:1::4"
  }

  expect_failures = [var.next_hop_in_ip_address]
}
