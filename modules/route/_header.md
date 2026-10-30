# Route

One user-defined route in a route table (`Microsoft.Network/routeTables/routes`), written as a child
resource. The root module calls it once per route when the table holds routes Azure adds itself
(`azure_managed_routes_enabled`); it can also be called alone with a table's resource ID.

A route written this way changes only itself: the table's other routes, Azure's included, are left as
they are. Writes lock the table's ID, so a table's routes are written one at a time.
