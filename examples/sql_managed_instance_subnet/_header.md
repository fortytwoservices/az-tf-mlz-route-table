# SQL Managed Instance subnet example

The route table of a subnet for a SQL Managed Instance, with `azure_managed_routes_enabled`: a SQL Managed
Instance adds its own routes to the table when it is created (its network intent policy), and Azure then
refuses any write of the table without them. The table keeps Azure's routes, and the module writes its own
(here a default route to a hub firewall's address) as child resources. The subnet is delegated to
`Microsoft.Sql/managedInstances`, with its network security group; the instance itself is not deployed.

Run it with `scripts/e2e.sh examples/sql_managed_instance_subnet`: apply, a second plan that must be empty,
destroy.
