resource "azapi_resource" "this" {
  type      = var.resource_types.network_route_tables
  name      = var.name
  parent_id = var.parent_id
  location  = var.location
  # By default the routes are in the table's body, not child resources: Azure replaces a route table's routes
  # with the ones a PUT carries, so a table written without them (a tag change) loses every route. Routes are
  # sent in name order, with `nextHopIpAddress` null except for an appliance (Azure then reports no address).
  # With Azure-managed routes the body holds none (the key stays: azapi only overrides keys the body has),
  # and every write sends the table's live routes instead (`ignore_body_changes`). Either way the routes are
  # a list (see `local.no_routes`); azapi plans no change for the type alone (it keeps the state's body when
  # the two are semantically equal).
  body = {
    properties = {
      disableBgpRoutePropagation = !var.bgp_route_propagation_enabled
      routes = var.azure_managed_routes_enabled ? local.no_routes : [for name in sort(keys(local.routes)) : {
        name = name
        properties = {
          addressPrefix    = local.routes[name].address_prefix
          nextHopType      = local.routes[name].next_hop_type
          nextHopIpAddress = local.routes[name].next_hop_in_ip_address
        }
      }]
    }
  }
  ignore_body_changes = length(local.ignore_body_changes) > 0 ? local.ignore_body_changes : null
  # Compared by name, whatever order Azure returns them in; a removed route is a shorter list.
  list_unique_id_property = { "properties.routes" = "name" }
  response_export_values  = []
  retry                   = var.retry
  tags                    = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  # Azure deletes no route table a subnet uses (InUseRouteTableCannotBeDeleted). A replacement (a change of
  # `name`, `parent_id`, `location` or `azure_managed_routes_enabled`) therefore creates the new table first,
  # so that subnets in the same configuration move to it before the old one is deleted.
  lifecycle {
    create_before_destroy = true
    replace_triggered_by  = [terraform_data.azure_managed_routes]
  }
}

# Azure-managed routes can only be kept from the table's creation: `properties.routes` added to
# `ignore_body_changes` of a table whose state holds routes fails at plan (azapi 2.13.0: "tuple element size
# not match"), and removed, the next write drops Azure's routes. So switching the mode replaces the table.
# Created by an upgrade from v0.1.0 without replacing anything: replace_triggered_by fires on an update or
# replacement of this, not on its creation (Terraform 1.17.0).
resource "terraform_data" "azure_managed_routes" {
  triggers_replace = var.azure_managed_routes_enabled
}
