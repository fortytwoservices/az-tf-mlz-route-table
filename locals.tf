locals {
  # Keyed by route name, the name Azure matches routes by.
  routes = { for route in values(var.routes) : route.name => route }

  # On an update, azapi reads the table and sends its live value at an ignored path, so with Azure-managed
  # routes every write carries Azure's routes and the module's child routes.
  ignore_body_changes = var.azure_managed_routes_enabled ? distinct(concat(var.ignore_body_changes.network_route_tables, ["properties.routes"])) : var.ignore_body_changes.network_route_tables

  # The lock is removed around a change of the table's children. Child routes (Azure-managed routes) are
  # passed as children always: a CanNotDelete lock also refuses deleting one (ScopeLocked, sandbox
  # 2026-10-29). Routes in the body only under a ReadOnly lock, which refuses every write of the table; a
  # CanNotDelete lock lets a table write remove routes, so it stays in place. The table's own settings
  # (tags, BGP propagation) stay locked either way.
  lock_dependencies = merge(
    { for name, route in module.route : name => route.lock_dependency },
    !var.azure_managed_routes_enabled && try(var.lock.kind, null) == "ReadOnly" ? { routes = sha256(jsonencode(azapi_resource.this.body.properties.routes)) } : {},
  )
}
