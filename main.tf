resource "azapi_resource" "this" {
  type      = var.resource_types.network_route_tables
  name      = var.name
  parent_id = var.parent_id
  location  = var.location
  # The routes are in the table's body, not child resources: Azure replaces a route table's routes with the
  # ones a PUT carries, so a table written without them (a tag change) loses every route. Routes are sent in
  # name order, with `nextHopIpAddress` null except for an appliance (Azure then reports no address).
  body = {
    properties = {
      disableBgpRoutePropagation = !var.bgp_route_propagation_enabled
      routes = [for name in sort(keys(local.routes)) : {
        name = name
        properties = {
          addressPrefix    = local.routes[name].address_prefix
          nextHopType      = local.routes[name].next_hop_type
          nextHopIpAddress = local.routes[name].next_hop_in_ip_address
        }
      }]
    }
  }
  ignore_body_changes = length(var.ignore_body_changes.network_route_tables) > 0 ? var.ignore_body_changes.network_route_tables : null
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
  # `name`, `parent_id` or `location`) therefore creates the new table first, so that subnets in the same
  # configuration move to it before the old one is deleted.
  lifecycle {
    create_before_destroy = true
  }
}
