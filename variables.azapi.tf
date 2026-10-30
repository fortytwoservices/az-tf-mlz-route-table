variable "ignore_body_changes" {
  type = object({
    network_route_tables           = optional(list(string), [])
    authorization_locks            = optional(list(string), [])
    authorization_role_assignments = optional(list(string), [])

    network_route_tables_routes = optional(object({
      network_route_tables_routes = optional(list(string), [])
    }), {})
  })
  default     = {}
  description = <<DESCRIPTION
Paths in each resource's `body` whose changes the AzAPI provider ignores. Prefer Terraform's `lifecycle.ignore_changes` when the paths are static; use this variable when the paths must be derived from variables or other non-static values.

Paths use dot notation, for example `properties.disableBgpRoutePropagation`. Individual list items cannot be targeted; ignore the whole list property instead. Configuration changes at an ignored path are **not** sent to Azure until that path is removed from the list. Changes take effect only after an apply, because the value is held in provider-private state.

- `network_route_tables` - Ignored body paths for the route table. With `azure_managed_routes_enabled`, the module adds `properties.routes`.
- `authorization_locks` - Ignored body paths for the route table's lock.
- `authorization_role_assignments` - Ignored body paths for the route table's role assignments.
- `network_route_tables_routes` - Slot for the `route` submodule (Azure-managed routes only).
  - `network_route_tables_routes` - Ignored body paths for each route.
DESCRIPTION
  nullable    = false
}

variable "resource_types" {
  type = object({
    network_route_tables           = optional(string, "Microsoft.Network/routeTables@2025-07-01")
    authorization_locks            = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")

    network_route_tables_routes = optional(object({
      network_route_tables_routes = optional(string)
    }), {})
  })
  default     = {}
  description = <<DESCRIPTION
Override the AzAPI `<provider>/<resource>@<api-version>` strings used by this module and its submodule. Each key defaults to a tested value; supply only the keys you want to override.

- `network_route_tables` - The route table.
- `authorization_locks` - The lock on the route table.
- `authorization_role_assignments` - Role assignments on the route table.
- `network_route_tables_routes` - Slot for the `route` submodule (Azure-managed routes only). Defaults live in the submodule.
  - `network_route_tables_routes` - Each route.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = <<DESCRIPTION
Retry configuration applied to every `azapi` resource managed by the module and the module it calls. Defaults to `null` (no custom retry).

- `error_message_regex`  - (Optional) A list of regex patterns matching error messages that trigger a retry.
- `interval_seconds`     - (Optional) Initial interval between retries in seconds.
- `max_interval_seconds` - (Optional) Maximum interval between retries in seconds.

See <https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource#retry> for full semantics.
DESCRIPTION
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
Default per-operation timeouts applied to every `azapi` resource managed by the module and the module it calls. Defaults to `null` (provider defaults). Each value is a Go duration string (e.g. `30m`, `1h`).

- `create` - (Optional) Timeout for create operations.
- `read`   - (Optional) Timeout for read operations.
- `update` - (Optional) Timeout for update operations.
- `delete` - (Optional) Timeout for delete operations.
DESCRIPTION
}
