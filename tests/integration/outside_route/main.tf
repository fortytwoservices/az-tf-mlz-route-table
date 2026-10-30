# Stands in for a route Azure adds to a table itself, as a SQL Managed Instance's network intent policy
# does: written by a PUT of the child route outside the module. Terraform never deletes it (a destroyed
# action does nothing); it goes with the table.
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
  }
}

variable "route_table_id" {
  type = string
}

resource "azapi_resource_action" "route" {
  type        = "Microsoft.Network/routeTables/routes@2025-07-01"
  resource_id = "${var.route_table_id}/routes/Microsoft.Sql-managedInstances_UseOnly_stand-in"
  method      = "PUT"
  body = {
    properties = {
      addressPrefix = "10.90.0.0/27"
      nextHopType   = "VnetLocal"
    }
  }
}
