# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> scripts/integration.sh .
# Azure-managed routes (`azure_managed_routes_enabled`), without a SQL Managed Instance: a route written
# outside the module stands in for the routes Azure adds itself. Proves, reading the table back from
# Azure after every write: the outside route survives a write of the table (tags, BGP propagation) and the
# module's route changes, under a CanNotDelete lock (a route deleted with the lock removed around it) and a
# ReadOnly lock; the module never plans to remove it (the last plan holds no change of the table's body).
# Then a table a subnet uses is switched into the mode and back, each a replacement under a new name.

run "setup" {
  module {
    source = "./tests/integration/setup"
  }
}

run "create" {
  variables {
    name                         = "rt-mlz-it-amr-${run.setup.suffix}"
    parent_id                    = run.setup.resource_group_id
    location                     = run.setup.location
    azure_managed_routes_enabled = true
    routes = {
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" }
      onprem  = { name = "onprem", address_prefix = "192.168.0.0/16", next_hop_type = "VirtualNetworkGateway" }
    }
    tags = { test = "create" }
    lock = { kind = "CanNotDelete" }
  }

  assert {
    condition     = jsonencode(keys(module.route)) == jsonencode(["default", "onprem"]) && module.interfaces.lock_resource_id != null
    error_message = "Each route should be a child resource, and the table locked."
  }
}

run "outside_route" {
  module {
    source = "./tests/integration/outside_route"
  }

  variables {
    route_table_id = run.create.resource_id
  }
}

run "read_with_outside_route" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    route_table_id = run.create.resource_id
  }

  assert {
    condition     = jsonencode(keys(output.routes)) == jsonencode(["Microsoft.Sql-managedInstances_UseOnly_stand-in", "default", "onprem"])
    error_message = "Azure should hold the module's two routes and the outside one: ${jsonencode(output.routes)}."
  }
}

run "update" {
  # A write of the table (new tags, BGP propagation off) and of its routes: default's address changed,
  # onprem removed (a child deleted under the CanNotDelete lock), spoke2 added.
  variables {
    name                         = "rt-mlz-it-amr-${run.setup.suffix}"
    parent_id                    = run.setup.resource_group_id
    location                     = run.setup.location
    azure_managed_routes_enabled = true
    routes = {
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.5" }
      spoke2  = { name = "spoke2", address_prefix = "10.100.9.0/24", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.5" }
    }
    bgp_route_propagation_enabled = false
    tags                          = { test = "update" }
    lock                          = { kind = "CanNotDelete" }
  }

  assert {
    condition     = output.resource_id == run.create.resource_id && module.interfaces.lock_resource_id != null
    error_message = "The table should be updated in place and stay locked."
  }
}

run "outside_route_survives" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    route_table_id = run.update.resource_id
  }

  assert {
    condition = jsonencode(output.routes) == jsonencode({
      "Microsoft.Sql-managedInstances_UseOnly_stand-in" = { address_prefix = "10.90.0.0/27", next_hop_in_ip_address = null, next_hop_type = "VnetLocal" }
      default                                           = { address_prefix = "0.0.0.0/0", next_hop_in_ip_address = "10.100.0.5", next_hop_type = "VirtualAppliance" }
      spoke2                                            = { address_prefix = "10.100.9.0/24", next_hop_in_ip_address = "10.100.0.5", next_hop_type = "VirtualAppliance" }
    })
    error_message = "The outside route should survive, with default's new address, spoke2 and no onprem: ${jsonencode(output.routes)}."
  }
  assert {
    condition     = !output.bgp_route_propagation_enabled && jsonencode(output.tags) == jsonencode({ test = "update" })
    error_message = "Azure should hold BGP propagation off and the new tags."
  }
}

run "readonly_lock" {
  variables {
    name                         = "rt-mlz-it-amr-${run.setup.suffix}"
    parent_id                    = run.setup.resource_group_id
    location                     = run.setup.location
    azure_managed_routes_enabled = true
    routes = {
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.5" }
      spoke2  = { name = "spoke2", address_prefix = "10.100.9.0/24", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.5" }
    }
    bgp_route_propagation_enabled = false
    tags                          = { test = "update" }
    lock                          = { kind = "ReadOnly" }
  }

  assert {
    condition     = endswith(module.interfaces.lock_resource_id, "/lock-ReadOnly")
    error_message = "The table should have its ReadOnly lock."
  }
}

run "change_routes_under_readonly_lock" {
  # The lock is removed around the route writes and created again: default's address back, and spoke2
  # renamed spoke3 under the same key, which replaces the route (deleted, then created).
  variables {
    name                         = "rt-mlz-it-amr-${run.setup.suffix}"
    parent_id                    = run.setup.resource_group_id
    location                     = run.setup.location
    azure_managed_routes_enabled = true
    routes = {
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" }
      spoke2  = { name = "spoke3", address_prefix = "10.100.10.0/24", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" }
    }
    bgp_route_propagation_enabled = false
    tags                          = { test = "update" }
    lock                          = { kind = "ReadOnly" }
  }

  assert {
    condition     = jsonencode(keys(module.route)) == jsonencode(["default", "spoke2"]) && module.route["spoke2"].name == "spoke3" && endswith(module.interfaces.lock_resource_id, "/lock-ReadOnly")
    error_message = "The routes should be changed, spoke2 renamed, and the table locked ReadOnly again."
  }
}

run "read_changed_under_readonly_lock" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    route_table_id = run.change_routes_under_readonly_lock.resource_id
  }

  assert {
    condition = jsonencode(output.routes) == jsonencode({
      "Microsoft.Sql-managedInstances_UseOnly_stand-in" = { address_prefix = "10.90.0.0/27", next_hop_in_ip_address = null, next_hop_type = "VnetLocal" }
      default                                           = { address_prefix = "0.0.0.0/0", next_hop_in_ip_address = "10.100.0.4", next_hop_type = "VirtualAppliance" }
      spoke3                                            = { address_prefix = "10.100.10.0/24", next_hop_in_ip_address = "10.100.0.4", next_hop_type = "VirtualAppliance" }
    })
    error_message = "Azure should hold the outside route, default's address back, spoke3 and no spoke2: ${jsonencode(output.routes)}."
  }
}

run "route_api_version_under_readonly_lock" {
  # Only the routes' API version changes: azapi writes each route again, which the ReadOnly lock refuses, so
  # the routes' lock_dependency changes with the version and the lock is removed around the writes.
  variables {
    name                         = "rt-mlz-it-amr-${run.setup.suffix}"
    parent_id                    = run.setup.resource_group_id
    location                     = run.setup.location
    azure_managed_routes_enabled = true
    routes = {
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" }
      spoke2  = { name = "spoke3", address_prefix = "10.100.10.0/24", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" }
    }
    bgp_route_propagation_enabled = false
    tags                          = { test = "update" }
    lock                          = { kind = "ReadOnly" }
    resource_types = {
      network_route_tables_routes = { network_route_tables_routes = "Microsoft.Network/routeTables/routes@2025-05-01" }
    }
  }

  assert {
    condition     = output.resource_id == run.create.resource_id && endswith(module.interfaces.lock_resource_id, "/lock-ReadOnly")
    error_message = "The routes should be written with the new API version and the table locked ReadOnly again."
  }
}

run "no_change_planned" {
  # azapi sets `output` unknown whenever it plans a change of the body, which fails this assertion: so the
  # outside route, which Azure reports and the configuration does not hold, plans no change.
  command = plan

  variables {
    resource_types = {
      network_route_tables_routes = { network_route_tables_routes = "Microsoft.Network/routeTables/routes@2025-05-01" }
    }
    name                         = "rt-mlz-it-amr-${run.setup.suffix}"
    parent_id                    = run.setup.resource_group_id
    location                     = run.setup.location
    azure_managed_routes_enabled = true
    routes = {
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" }
      spoke2  = { name = "spoke3", address_prefix = "10.100.10.0/24", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" }
    }
    bgp_route_propagation_enabled = false
    tags                          = { test = "update" }
    lock                          = { kind = "ReadOnly" }
  }

  assert {
    condition     = jsonencode(azapi_resource.this.output) == jsonencode({})
    error_message = "The table should plan no change of its body."
  }
}

# Switching the mode of a table a subnet uses, under a CanNotDelete lock: the table is replaced under a new
# name; the new table and its routes are written first, then the subnet moves, then the old table goes.

run "associated_create" {
  module {
    source = "./tests/integration/associated"
  }

  variables {
    location          = run.setup.location
    resource_group_id = run.setup.resource_group_id
    route_table_name  = "rt-mlz-it-amr-assoc-${run.setup.suffix}"
    suffix            = run.setup.suffix
  }
}

run "switch_to_azure_managed_routes" {
  # Planned against the old state first (its routes in the body), then replaced.
  module {
    source = "./tests/integration/associated"
  }

  variables {
    azure_managed_routes_enabled = true
    location                     = run.setup.location
    resource_group_id            = run.setup.resource_group_id
    route_table_name             = "rt-mlz-it-amr-assoc-${run.setup.suffix}-managed"
    suffix                       = run.setup.suffix
  }

  assert {
    condition     = output.resource_id != run.associated_create.resource_id && output.subnet_id == run.associated_create.subnet_id
    error_message = "The table should be replaced and the subnet kept."
  }
}

run "read_switched_to_azure_managed_routes" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    route_table_id = run.switch_to_azure_managed_routes.resource_id
  }

  assert {
    condition     = jsonencode(output.subnet_ids) == jsonencode([lower(run.switch_to_azure_managed_routes.subnet_id)]) && output.routes.default.next_hop_in_ip_address == "10.100.0.4" && length(output.routes) == 1
    error_message = "The subnet should use the new table, which has the default route as a child route: ${jsonencode(output.routes)}."
  }
}

run "switch_back" {
  module {
    source = "./tests/integration/associated"
  }

  variables {
    azure_managed_routes_enabled = false
    location                     = run.setup.location
    resource_group_id            = run.setup.resource_group_id
    route_table_name             = "rt-mlz-it-amr-assoc-${run.setup.suffix}-inline"
    suffix                       = run.setup.suffix
  }

  assert {
    condition     = output.resource_id != run.switch_to_azure_managed_routes.resource_id && output.subnet_id == run.associated_create.subnet_id
    error_message = "The table should be replaced again and the subnet kept."
  }
}

run "read_switched_back" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    route_table_id = run.switch_back.resource_id
  }

  assert {
    condition     = jsonencode(output.subnet_ids) == jsonencode([lower(run.switch_back.subnet_id)]) && output.routes.default.next_hop_in_ip_address == "10.100.0.4" && length(output.routes) == 1
    error_message = "The subnet should use the newest table, which has the default route in its body: ${jsonencode(output.routes)}."
  }
}
