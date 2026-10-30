# With Azure-managed routes only: each route is its own child resource, so writing it leaves the table's
# other routes, Azure's included, as they are. Keyed by the caller's keys, which are known when planning,
# so a route's name may be known only after apply.
module "route" {
  source   = "./modules/route"
  for_each = var.azure_managed_routes_enabled ? var.routes : {}

  name                   = each.value.name
  parent_id              = azapi_resource.this.id
  address_prefix         = each.value.address_prefix
  next_hop_type          = each.value.next_hop_type
  next_hop_in_ip_address = each.value.next_hop_in_ip_address
  ignore_body_changes    = var.ignore_body_changes.network_route_tables_routes
  resource_types         = var.resource_types.network_route_tables_routes
  retry                  = var.retry
  timeouts               = var.timeouts
}
