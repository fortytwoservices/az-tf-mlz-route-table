# az-tf-mlz-route-table

A Fortytwo managed landing zone (MLZ) module for an Azure route table, in AzAPI: the route table
(`Microsoft.Network/routeTables`) and its user-defined routes, for a hub's subnets and for spokes.

- **The routes are in the table's body**, not child resources. Azure replaces a table's routes with the ones
  a write of the table carries, so a table written without them loses every route on any change of the
  table (a tag change) until the routes are written again. Every write here carries them all, matched by
  name, and a removed route is removed from Azure.
- **Tables Azure adds routes to** (`azure_managed_routes_enabled`, set at creation only). A SQL Managed
  Instance adds its own routes to its subnet's table (its network intent policy), and Azure refuses any
  write of the table without them. With this set, every write of the table sends the routes it holds in
  Azure at that moment, and the module's routes are child resources (`modules/route`), so the module
  adds, changes and removes only its own. Changing it replaces the table, which needs a new `name`.
- **`routes` takes the shape of subscription vending's route table routes** (`Azure/avm-ptn-alz-sub-vending`)
  and of the connectivity compositions' `spoke_default_routes`, which can be passed straight in: a map of
  `name`, `address_prefix` (a CIDR prefix or a service tag), `next_hop_type` and, for a `VirtualAppliance`
  only, `next_hop_in_ip_address`. Up to 400 routes, 25 of them with service tags.
- **Gateway route propagation** is on by default (`bgp_route_propagation_enabled`), as Azure has it and as
  `GatewaySubnet` needs it. A spoke behind a hub firewall turns it off, so that on-premises prefixes learned
  over BGP do not bypass the firewall.
- **Subnets attach themselves**: a subnet sets `routeTable.id` to `resource_id`, as in the example. Azure
  deletes no route table a subnet uses, so a replacement (a change of `name`, `parent_id`, `location` or
  `azure_managed_routes_enabled`) creates the new table first: subnets in the same configuration move to
  it, then the old one is deleted. Subnets elsewhere must move before the old table can go, and a
  replacement for another reason than a rename also needs a new `name`.
- **Locks.** A `ReadOnly` lock refuses every write of the table, so it is removed around a change of the
  routes (the table's children) and created again afterwards, as for any MLZ module's children; a change
  of the table's own settings (`tags`, `bgp_route_propagation_enabled`) alone is refused until the lock is
  removed. A `CanNotDelete` lock stays in place while routes in the body are added, changed or removed;
  with Azure-managed routes it is removed around a route's change too, because it refuses deleting a child
  route.
- Lock and role assignments, as in Azure Verified Modules, through
  [`az-tf-mlz-interfaces`](https://github.com/fortytwoservices/az-tf-mlz-interfaces). Route tables have no
  diagnostic settings.
- Not covered: disabling peering routes (`disablePeeringRoute`, in preview) and ECMP next hops
  (`VirtualApplianceEcmp`).

```hcl
module "spoke_route_table" {
  source = "git::https://github.com/fortytwoservices/az-tf-mlz-route-table.git?ref=vX.Y.Z"

  name                          = "rt-spoke-swc"
  parent_id                     = "/subscriptions/<subscription>/resourceGroups/<resource group>"
  location                      = "swedencentral"
  routes                        = module.connectivity.connectivity.regions["swedencentral"].spoke_default_routes
  bgp_route_propagation_enabled = false
}
```

The examples deploy a hub's `AzureFirewallSubnet` table and a spoke's table, each used by a subnet
(`default`), and the table of a subnet for a SQL Managed Instance (`sql_managed_instance_subnet`).
