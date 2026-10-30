locals {
  # Keyed by route name, the name Azure matches routes by.
  routes = { for route in values(var.routes) : route.name => route }

  # Routes are the table's children (routeTables/routes), written in its body. A ReadOnly lock refuses
  # every write of the table (ScopeLocked), so with one the lock is removed around a change of the routes,
  # as around any child's change; the table's own settings (tags, BGP propagation) stay locked. A
  # CanNotDelete lock lets a table write remove routes (sandbox, 2026-10-29), so it stays in place.
  lock_dependencies = try(var.lock.kind, null) == "ReadOnly" ? { routes = sha256(jsonencode(azapi_resource.this.body.properties.routes)) } : {}
}
