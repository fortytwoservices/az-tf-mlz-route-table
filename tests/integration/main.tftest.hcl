# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> scripts/integration.sh .
# Proves what mocks cannot, reading the table back from Azure after every write: every next hop type, a
# service tag and an IPv6 route are accepted; a change of the table itself (tags, BGP propagation) keeps
# every route, which is why the routes are in the table's body; routes are added, changed and removed under
# a CanNotDelete lock and under a ReadOnly lock; a table a subnet uses is replaced (renamed) under its lock,
# the subnet moving to the new table before the old one is deleted. Free: route tables cost nothing.

run "setup" {
  module {
    source = "./tests/integration/setup"
  }
}

run "create" {
  variables {
    name      = "rt-mlz-it-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    routes = {
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" }
      onprem  = { name = "onprem", address_prefix = "192.168.0.0/16", next_hop_type = "VirtualNetworkGateway" }
      drop    = { name = "drop", address_prefix = "10.200.0.0/16", next_hop_type = "None" }
      local   = { name = "local", address_prefix = "10.100.8.0/24", next_hop_type = "VnetLocal" }
      storage = { name = "storage", address_prefix = "Storage.SwedenCentral", next_hop_type = "Internet" }
      v6      = { name = "v6", address_prefix = "fd00:db8::/48", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "fd00:db8:1::4" }
    }
    tags = { test = "create" }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
  }

  assert {
    condition     = module.interfaces.lock_resource_id != null && jsonencode(keys(module.interfaces.role_assignment_resource_ids)) == jsonencode(["reader"])
    error_message = "The table should be locked and have its role assignment."
  }
}

run "read_created" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    route_table_id = run.create.resource_id
  }

  assert {
    condition = jsonencode(output.routes) == jsonencode({
      default = { address_prefix = "0.0.0.0/0", next_hop_in_ip_address = "10.100.0.4", next_hop_type = "VirtualAppliance" }
      drop    = { address_prefix = "10.200.0.0/16", next_hop_in_ip_address = null, next_hop_type = "None" }
      local   = { address_prefix = "10.100.8.0/24", next_hop_in_ip_address = null, next_hop_type = "VnetLocal" }
      onprem  = { address_prefix = "192.168.0.0/16", next_hop_in_ip_address = null, next_hop_type = "VirtualNetworkGateway" }
      storage = { address_prefix = "Storage.SwedenCentral", next_hop_in_ip_address = null, next_hop_type = "Internet" }
      v6      = { address_prefix = "fd00:db8::/48", next_hop_in_ip_address = "fd00:db8:1::4", next_hop_type = "VirtualAppliance" }
    })
    error_message = "Azure should hold the six routes as sent: ${jsonencode(output.routes)}."
  }
  assert {
    condition     = output.bgp_route_propagation_enabled && jsonencode(output.tags) == jsonencode({ test = "create" })
    error_message = "Azure should hold BGP propagation on and the tags."
  }
}

run "update_table" {
  # A change of the table itself: new tags and BGP propagation off, the routes as they are.
  variables {
    name      = "rt-mlz-it-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    routes = {
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" }
      onprem  = { name = "onprem", address_prefix = "192.168.0.0/16", next_hop_type = "VirtualNetworkGateway" }
      drop    = { name = "drop", address_prefix = "10.200.0.0/16", next_hop_type = "None" }
      local   = { name = "local", address_prefix = "10.100.8.0/24", next_hop_type = "VnetLocal" }
      storage = { name = "storage", address_prefix = "Storage.SwedenCentral", next_hop_type = "Internet" }
      v6      = { name = "v6", address_prefix = "fd00:db8::/48", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "fd00:db8:1::4" }
    }
    bgp_route_propagation_enabled = false
    tags                          = { test = "update" }
    lock                          = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
  }

  assert {
    condition     = output.resource_id == run.create.resource_id
    error_message = "The table should be updated in place."
  }
}

run "routes_survive_table_update" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    route_table_id = run.update_table.resource_id
  }

  assert {
    condition     = jsonencode(keys(output.routes)) == jsonencode(["default", "drop", "local", "onprem", "storage", "v6"]) && output.routes.default.next_hop_in_ip_address == "10.100.0.4"
    error_message = "Every route should survive the update of the table: ${jsonencode(output.routes)}."
  }
  assert {
    condition     = !output.bgp_route_propagation_enabled && jsonencode(output.tags) == jsonencode({ test = "update" })
    error_message = "Azure should hold BGP propagation off and the new tags."
  }
}

run "change_routes" {
  # Under the CanNotDelete lock, which stays in place: a route added (spoke2), one changed (default's
  # address) and one removed (drop); BGP propagation back on.
  variables {
    name      = "rt-mlz-it-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    routes = {
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.5" }
      onprem  = { name = "onprem", address_prefix = "192.168.0.0/16", next_hop_type = "VirtualNetworkGateway" }
      local   = { name = "local", address_prefix = "10.100.8.0/24", next_hop_type = "VnetLocal" }
      storage = { name = "storage", address_prefix = "Storage.SwedenCentral", next_hop_type = "Internet" }
      v6      = { name = "v6", address_prefix = "fd00:db8::/48", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "fd00:db8:1::4" }
      spoke2  = { name = "spoke2", address_prefix = "10.100.9.0/24", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.5" }
    }
    tags = { test = "update" }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
  }

  assert {
    condition     = output.resource_id == run.create.resource_id && module.interfaces.lock_resource_id != null
    error_message = "The table should be updated in place and stay locked."
  }
}

run "read_changed" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    route_table_id = run.change_routes.resource_id
  }

  assert {
    condition = jsonencode(output.routes) == jsonencode({
      default = { address_prefix = "0.0.0.0/0", next_hop_in_ip_address = "10.100.0.5", next_hop_type = "VirtualAppliance" }
      local   = { address_prefix = "10.100.8.0/24", next_hop_in_ip_address = null, next_hop_type = "VnetLocal" }
      onprem  = { address_prefix = "192.168.0.0/16", next_hop_in_ip_address = null, next_hop_type = "VirtualNetworkGateway" }
      spoke2  = { address_prefix = "10.100.9.0/24", next_hop_in_ip_address = "10.100.0.5", next_hop_type = "VirtualAppliance" }
      storage = { address_prefix = "Storage.SwedenCentral", next_hop_in_ip_address = null, next_hop_type = "Internet" }
      v6      = { address_prefix = "fd00:db8::/48", next_hop_in_ip_address = "fd00:db8:1::4", next_hop_type = "VirtualAppliance" }
    })
    error_message = "Azure should hold spoke2, default's new address and no drop route: ${jsonencode(output.routes)}."
  }
  assert {
    condition     = output.bgp_route_propagation_enabled
    error_message = "Azure should hold BGP propagation on again."
  }
}

run "readonly_lock" {
  variables {
    name      = "rt-mlz-it-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    routes = {
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.5" }
      onprem  = { name = "onprem", address_prefix = "192.168.0.0/16", next_hop_type = "VirtualNetworkGateway" }
      local   = { name = "local", address_prefix = "10.100.8.0/24", next_hop_type = "VnetLocal" }
      storage = { name = "storage", address_prefix = "Storage.SwedenCentral", next_hop_type = "Internet" }
      v6      = { name = "v6", address_prefix = "fd00:db8::/48", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "fd00:db8:1::4" }
      spoke2  = { name = "spoke2", address_prefix = "10.100.9.0/24", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.5" }
    }
    tags = { test = "update" }
    lock = { kind = "ReadOnly" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
  }

  assert {
    condition     = endswith(module.interfaces.lock_resource_id, "/lock-ReadOnly")
    error_message = "The table should have its ReadOnly lock."
  }
}

run "change_routes_under_readonly_lock" {
  # Azure refuses any write of a table under a ReadOnly lock, so the lock is removed around the change of
  # the routes and created again: drop added back, onprem's prefix changed, storage removed.
  variables {
    name      = "rt-mlz-it-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    routes = {
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.5" }
      onprem  = { name = "onprem", address_prefix = "172.16.0.0/12", next_hop_type = "VirtualNetworkGateway" }
      drop    = { name = "drop", address_prefix = "10.200.0.0/16", next_hop_type = "None" }
      local   = { name = "local", address_prefix = "10.100.8.0/24", next_hop_type = "VnetLocal" }
      v6      = { name = "v6", address_prefix = "fd00:db8::/48", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "fd00:db8:1::4" }
      spoke2  = { name = "spoke2", address_prefix = "10.100.9.0/24", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.5" }
    }
    tags = { test = "update" }
    lock = { kind = "ReadOnly" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
  }

  assert {
    condition     = output.resource_id == run.create.resource_id && endswith(module.interfaces.lock_resource_id, "/lock-ReadOnly")
    error_message = "The table should be updated in place and locked ReadOnly again."
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
      default = { address_prefix = "0.0.0.0/0", next_hop_in_ip_address = "10.100.0.5", next_hop_type = "VirtualAppliance" }
      drop    = { address_prefix = "10.200.0.0/16", next_hop_in_ip_address = null, next_hop_type = "None" }
      local   = { address_prefix = "10.100.8.0/24", next_hop_in_ip_address = null, next_hop_type = "VnetLocal" }
      onprem  = { address_prefix = "172.16.0.0/12", next_hop_in_ip_address = null, next_hop_type = "VirtualNetworkGateway" }
      spoke2  = { address_prefix = "10.100.9.0/24", next_hop_in_ip_address = "10.100.0.5", next_hop_type = "VirtualAppliance" }
      v6      = { address_prefix = "fd00:db8::/48", next_hop_in_ip_address = "fd00:db8:1::4", next_hop_type = "VirtualAppliance" }
    })
    error_message = "Azure should hold drop again, onprem's new prefix and no storage route: ${jsonencode(output.routes)}."
  }
}

run "associated_create" {
  module {
    source = "./tests/integration/associated"
  }

  variables {
    location          = run.setup.location
    resource_group_id = run.setup.resource_group_id
    route_table_name  = "rt-mlz-it-assoc-${run.setup.suffix}"
    suffix            = run.setup.suffix
  }
}

run "read_associated" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    route_table_id = run.associated_create.resource_id
  }

  assert {
    condition     = jsonencode(output.subnet_ids) == jsonencode([lower(run.associated_create.subnet_id)]) && !output.bgp_route_propagation_enabled
    error_message = "The subnet should use the table, which has BGP propagation off."
  }
}

run "associated_rename" {
  # A rename replaces the table: the new one is created, the subnet moves to it, then the old one, no
  # longer in use, is deleted; the CanNotDelete lock moves along.
  module {
    source = "./tests/integration/associated"
  }

  variables {
    location          = run.setup.location
    resource_group_id = run.setup.resource_group_id
    route_table_name  = "rt-mlz-it-assoc-${run.setup.suffix}-renamed"
    suffix            = run.setup.suffix
  }

  assert {
    condition     = output.resource_id != run.associated_create.resource_id && output.subnet_id == run.associated_create.subnet_id
    error_message = "The table should be replaced and the subnet kept."
  }
}

run "read_renamed" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    route_table_id = run.associated_rename.resource_id
  }

  assert {
    condition     = jsonencode(output.subnet_ids) == jsonencode([lower(run.associated_rename.subnet_id)]) && jsonencode(keys(output.routes)) == jsonencode(["default"])
    error_message = "The subnet should use the new table, which has the default route."
  }
}
