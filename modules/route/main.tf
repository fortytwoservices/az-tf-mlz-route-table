resource "azapi_resource" "this" {
  type      = var.resource_types.network_route_tables_routes
  name      = var.name
  parent_id = var.parent_id
  # The address is sent as null except for an appliance; Azure then reports no address.
  body = {
    properties = {
      addressPrefix    = var.address_prefix
      nextHopType      = var.next_hop_type
      nextHopIpAddress = var.next_hop_in_ip_address
    }
  }
  ignore_body_changes = length(var.ignore_body_changes.network_route_tables_routes) > 0 ? var.ignore_body_changes.network_route_tables_routes : null
  # One write at a time per table: every route write updates the table.
  locks                  = [var.parent_id]
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}
