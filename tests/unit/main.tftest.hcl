mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/routeTables/rt-test"
    }
  }
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [
          {
            id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
            role_name = "Reader"
          }
        ]
      }
    }
  }
}
mock_provider "random" {}
mock_provider "time" {}

variables {
  location  = "swedencentral"
  name      = "rt-test"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
}

run "defaults" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/routeTables@2025-07-01" && azapi_resource.this.name == var.name && azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.location == var.location
    error_message = "The route table should use the default resource type, name, parent_id and location."
  }
  assert {
    condition     = jsonencode(azapi_resource.this.body) == jsonencode({ properties = { disableBgpRoutePropagation = false, routes = [] } })
    error_message = "Without routes, the body should send an empty route list (so removing the last route reaches Azure) and BGP propagation on."
  }
  assert {
    condition     = jsonencode(azapi_resource.this.list_unique_id_property) == jsonencode({ "properties.routes" = "name" })
    error_message = "Routes should be compared by name."
  }
  assert {
    condition     = azapi_resource.this.ignore_body_changes == null && azapi_resource.this.retry == null && azapi_resource.this.timeouts == null
    error_message = "ignore_body_changes, retry and timeouts should be unset by default."
  }
  assert {
    condition     = length(coalesce(azapi_resource.this.tags, {})) == 0 # computed: the mock returns {}
    error_message = "tags should be unset by default."
  }
  assert {
    condition     = module.interfaces.lock_resource_id == null && length(module.interfaces.role_assignment_resource_ids) == 0 && length(local.lock_dependencies) == 0
    error_message = "No lock or role assignment should be created by default."
  }
  assert {
    condition     = output.resource_id == azapi_resource.this.id && output.name == var.name
    error_message = "resource_id and name should come from the route table."
  }
  assert {
    condition     = length(module.route) == 0 && length(local.ignore_body_changes) == 0 && terraform_data.azure_managed_routes.triggers_replace == false
    error_message = "By default the routes should be in the body: no child routes, no ignored body path, the mode recorded as false."
  }
}

run "routes" {
  command = apply

  # Keys differ from the names and from their order: the body follows the names.
  variables {
    bgp_route_propagation_enabled = false
    routes = {
      a = { name = "storage", address_prefix = "Storage.SwedenCentral", next_hop_type = "Internet" }
      b = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" }
      c = { name = "onprem", address_prefix = "192.168.0.0/16", next_hop_type = "VirtualNetworkGateway" }
      d = { name = "drop", address_prefix = "10.200.0.0/16", next_hop_type = "None" }
      e = { name = "local", address_prefix = "10.100.8.0/24", next_hop_type = "VnetLocal" }
      f = { name = "v6", address_prefix = "fd00:db8::/48", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "fd00:db8:1::4" }
    }
  }

  assert {
    condition = jsonencode(azapi_resource.this.body) == jsonencode({
      properties = {
        disableBgpRoutePropagation = true
        routes = [
          { name = "default", properties = { addressPrefix = "0.0.0.0/0", nextHopType = "VirtualAppliance", nextHopIpAddress = "10.100.0.4" } },
          { name = "drop", properties = { addressPrefix = "10.200.0.0/16", nextHopType = "None", nextHopIpAddress = null } },
          { name = "local", properties = { addressPrefix = "10.100.8.0/24", nextHopType = "VnetLocal", nextHopIpAddress = null } },
          { name = "onprem", properties = { addressPrefix = "192.168.0.0/16", nextHopType = "VirtualNetworkGateway", nextHopIpAddress = null } },
          { name = "storage", properties = { addressPrefix = "Storage.SwedenCentral", nextHopType = "Internet", nextHopIpAddress = null } },
          { name = "v6", properties = { addressPrefix = "fd00:db8::/48", nextHopType = "VirtualAppliance", nextHopIpAddress = "fd00:db8:1::4" } },
        ]
      }
    })
    error_message = "Routes should be sent in name order, every one with nextHopIpAddress (null except for an appliance), and BGP propagation off as disableBgpRoutePropagation = true."
  }
}

# The connectivity compositions' contract (`spoke_default_routes`), passed straight in.
run "spoke_default_routes" {
  command = apply

  variables {
    bgp_route_propagation_enabled = false
    routes = {
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" }
    }
  }

  assert {
    condition     = jsonencode(azapi_resource.this.body.properties.routes) == jsonencode([{ name = "default", properties = { addressPrefix = "0.0.0.0/0", nextHopType = "VirtualAppliance", nextHopIpAddress = "10.100.0.4" } }])
    error_message = "A spoke's default route to the firewall should be the table's only route."
  }
}

run "interfaces" {
  command = apply

  variables {
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = "55555555-5555-5555-5555-555555555555" }
    }
    routes = {
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "Internet" }
    }
  }

  assert {
    condition     = module.interfaces.lock_resource_id != null && jsonencode(keys(module.interfaces.role_assignment_resource_ids)) == jsonencode(["reader"])
    error_message = "The lock and role assignments should be created through az-tf-mlz-interfaces."
  }
  assert {
    condition     = length(local.lock_dependencies) == 0
    error_message = "A CanNotDelete lock lets a table write remove routes, so it should stay in place around route changes."
  }
}

run "readonly_lock" {
  command = apply

  variables {
    lock = { kind = "ReadOnly" }
    routes = {
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "Internet" }
    }
  }

  assert {
    condition     = jsonencode(local.lock_dependencies) == jsonencode({ routes = sha256(jsonencode(azapi_resource.this.body.properties.routes)) })
    error_message = "With a ReadOnly lock, the routes should be a lock dependency, so the lock is removed around their changes."
  }
}

run "azapi_settings" {
  command = apply

  variables {
    lock                = { kind = "CanNotDelete" }
    resource_types      = { network_route_tables = "Microsoft.Network/routeTables@2024-05-01" }
    ignore_body_changes = { network_route_tables = ["properties.disableBgpRoutePropagation"] }
    retry               = { error_message_regex = ["AnotherOperationInProgress"] }
    timeouts            = { create = "30m", update = "30m" }
    tags                = { environment = "test" }
  }

  # The interface keys of resource_types and ignore_body_changes, retry and timeouts also go to
  # az-tf-mlz-interfaces, whose tests check them; ignore_body_changes is write-only.
  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/routeTables@2024-05-01" && azapi_resource.this.tags == tomap({ environment = "test" })
    error_message = "resource_types and tags should reach the route table."
  }
  assert {
    condition     = azapi_resource.this.retry.error_message_regex == tolist(["AnotherOperationInProgress"]) && azapi_resource.this.timeouts.create == "30m" && azapi_resource.this.timeouts.update == "30m"
    error_message = "retry and timeouts should reach the route table."
  }
}

run "azure_managed_routes" {
  command = apply

  variables {
    azure_managed_routes_enabled = true
    lock                         = { kind = "CanNotDelete" }
    routes = {
      a = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" }
      b = { name = "onprem", address_prefix = "192.168.0.0/16", next_hop_type = "VirtualNetworkGateway" }
    }
  }

  assert {
    condition     = jsonencode(azapi_resource.this.body) == jsonencode({ properties = { disableBgpRoutePropagation = false, routes = [] } })
    error_message = "With Azure-managed routes, the body should hold no routes but keep the key, which azapi overrides with the live routes."
  }
  assert {
    condition     = jsonencode(local.ignore_body_changes) == jsonencode(["properties.routes"])
    error_message = "With Azure-managed routes, every table write should send the table's live routes."
  }
  assert {
    condition     = terraform_data.azure_managed_routes.triggers_replace == true
    error_message = "The mode should be recorded, so that changing it replaces the table."
  }
  assert {
    condition     = jsonencode(keys(module.route)) == jsonencode(["a", "b"]) && module.route["a"].name == "default" && module.route["b"].name == "onprem"
    error_message = "Each route should be a child resource, keyed by the caller's key (known when planning) and named by the route's name."
  }
  assert {
    condition     = jsonencode(local.lock_dependencies) == jsonencode({ for name, route in module.route : name => route.lock_dependency })
    error_message = "Child routes should be lock dependencies under any lock: a CanNotDelete lock also refuses deleting one."
  }
}

run "azure_managed_routes_readonly_lock" {
  command = apply

  variables {
    azure_managed_routes_enabled = true
    lock                         = { kind = "ReadOnly" }
    routes = {
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "Internet" }
    }
  }

  assert {
    condition     = jsonencode(keys(local.lock_dependencies)) == jsonencode(["default"])
    error_message = "Under a ReadOnly lock with Azure-managed routes, the child routes should be the only lock dependencies (no hash of a body without routes)."
  }
}

run "azure_managed_routes_settings" {
  command = apply

  variables {
    azure_managed_routes_enabled = true
    routes = {
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "Internet" }
    }
    resource_types = {
      network_route_tables_routes = { network_route_tables_routes = "Microsoft.Network/routeTables/routes@2024-05-01" }
    }
    ignore_body_changes = {
      network_route_tables = ["properties.disableBgpRoutePropagation", "properties.routes"]
    }
    retry    = { error_message_regex = ["AnotherOperationInProgress"] }
    timeouts = { create = "30m" }
  }

  # The submodule's own tests check that resource_types, ignore_body_changes, retry and timeouts reach its
  # resource; here only that the caller's ignored paths are kept and not repeated.
  assert {
    condition     = jsonencode(local.ignore_body_changes) == jsonencode(["properties.disableBgpRoutePropagation", "properties.routes"])
    error_message = "The caller's ignored paths should be kept, with properties.routes once."
  }
  assert {
    condition     = module.route["default"].resource_id != null
    error_message = "The route should be created with the overrides."
  }
}

run "invalid_name" {
  command = plan

  variables {
    name = "rt-test-"
  }

  expect_failures = [var.name]
}

run "invalid_parent_id" {
  command = plan

  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  }

  expect_failures = [var.parent_id]
}

run "invalid_route_name" {
  command = plan

  variables {
    routes = {
      default = { name = "default.", address_prefix = "0.0.0.0/0", next_hop_type = "Internet" }
    }
  }

  expect_failures = [var.routes]
}

run "duplicate_route_names" {
  command = plan

  variables {
    routes = {
      a = { name = "Default", address_prefix = "0.0.0.0/0", next_hop_type = "Internet" }
      b = { name = "default", address_prefix = "10.0.0.0/8", next_hop_type = "None" }
    }
  }

  expect_failures = [var.routes]
}

# The same name exactly: the validation fails before the routes are keyed by name.
run "same_route_name_twice" {
  command = plan

  variables {
    routes = {
      a = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "Internet" }
      b = { name = "default", address_prefix = "10.0.0.0/8", next_hop_type = "None" }
    }
  }

  expect_failures = [var.routes]
}

run "invalid_next_hop_type" {
  command = plan

  variables {
    routes = {
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualNetworkPeering" }
    }
  }

  expect_failures = [var.routes]
}

run "appliance_without_ip_address" {
  command = plan

  variables {
    routes = {
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance" }
    }
  }

  expect_failures = [var.routes]
}

run "ip_address_without_appliance" {
  command = plan

  variables {
    routes = {
      onprem = { name = "onprem", address_prefix = "192.168.0.0/16", next_hop_type = "VirtualNetworkGateway", next_hop_in_ip_address = "10.100.0.4" }
    }
  }

  expect_failures = [var.routes]
}

run "invalid_ip_address" {
  command = plan

  variables {
    routes = {
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.256" }
    }
  }

  expect_failures = [var.routes]
}

run "uncompressed_ipv6_address" {
  command = plan

  variables {
    routes = {
      v6 = { name = "v6", address_prefix = "fd00:db8::/48", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "FD00:DB8:1:0:0:0:0:4" }
    }
  }

  expect_failures = [var.routes]
}

run "host_bits_in_address_prefix" {
  command = plan

  variables {
    routes = {
      spoke = { name = "spoke", address_prefix = "10.100.8.1/24", next_hop_type = "None" }
    }
  }

  expect_failures = [var.routes]
}

run "invalid_address_prefix" {
  command = plan

  variables {
    routes = {
      spoke = { name = "spoke", address_prefix = "10.100.8.0", next_hop_type = "None" }
    }
  }

  expect_failures = [var.routes]
}

run "mixed_address_families" {
  command = plan

  variables {
    routes = {
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "fd00:db8:1::4" }
    }
  }

  expect_failures = [var.routes]
}

run "ipv6_to_gateway" {
  command = plan

  variables {
    routes = {
      v6 = { name = "v6", address_prefix = "fd00:db8::/48", next_hop_type = "VirtualNetworkGateway" }
    }
  }

  expect_failures = [var.routes]
}

run "too_many_routes" {
  command = plan

  variables {
    routes = { for i in range(401) : "r${i}" => { name = "r${i}", address_prefix = cidrsubnet("10.0.0.0/8", 16, i), next_hop_type = "None" } }
  }

  expect_failures = [var.routes]
}

run "too_many_service_tag_routes" {
  command = plan

  variables {
    routes = { for i in range(26) : "r${i}" => { name = "r${i}", address_prefix = "Tag${i}", next_hop_type = "Internet" } }
  }

  expect_failures = [var.routes]
}

run "invalid_lock_kind" {
  command = plan

  variables {
    lock = { kind = "DoNotDelete" }
  }

  expect_failures = [var.lock]
}
