variable "ignore_body_changes" {
  type = object({
    managedidentity_user_assigned_identities = optional(list(string), [])
    authorization_locks                      = optional(list(string), [])
    authorization_role_assignments           = optional(list(string), [])

    managedidentity_user_assigned_identities_federated_identity_credentials = optional(object({
      managedidentity_user_assigned_identities_federated_identity_credentials = optional(list(string), [])
    }), {})
  })
  default     = {}
  description = <<DESCRIPTION
Paths in each resource's `body` whose changes the AzAPI provider ignores. Prefer Terraform's `lifecycle.ignore_changes` when the paths are static; use this variable when the paths must be derived from variables or other non-static values.

Paths use dot notation, for example `properties.isolationScope`. Individual list items cannot be targeted; ignore the whole list property instead. Configuration changes at an ignored path are **not** sent to Azure until that path is removed from the list. Changes take effect only after an apply, because the value is held in provider-private state.

- `managedidentity_user_assigned_identities` - Ignored body paths for the user-assigned identity.
- `authorization_locks` - Ignored body paths for the lock.
- `authorization_role_assignments` - Ignored body paths for the role assignments.
- `managedidentity_user_assigned_identities_federated_identity_credentials` - Slot for the `federated_identity_credential` submodule.
  - `managedidentity_user_assigned_identities_federated_identity_credentials` - Ignored body paths for each federated identity credential.
DESCRIPTION
  nullable    = false
}

variable "resource_types" {
  type = object({
    managedidentity_user_assigned_identities = optional(string, "Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30")
    authorization_locks                      = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments           = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")

    managedidentity_user_assigned_identities_federated_identity_credentials = optional(object({
      managedidentity_user_assigned_identities_federated_identity_credentials = optional(string)
    }), {})
  })
  default     = {}
  description = <<DESCRIPTION
Override the AzAPI `<provider>/<resource>@<api-version>` strings used by this module and its submodule. Each key defaults to a tested value; supply only the keys you want to override.

- `managedidentity_user_assigned_identities` - The user-assigned identity.
- `authorization_locks` - The lock on the user-assigned identity.
- `authorization_role_assignments` - Role assignments on the user-assigned identity.
- `managedidentity_user_assigned_identities_federated_identity_credentials` - Slot for the `federated_identity_credential` submodule. Defaults live in the submodule.
  - `managedidentity_user_assigned_identities_federated_identity_credentials` - Each federated identity credential.
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
Retry configuration applied to every `azapi` resource managed by the module (root resource and all submodules). Defaults to `null` (no custom retry).

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
Default per-operation timeouts applied to every `azapi` resource managed by the module. Defaults to `null` (provider defaults). Each value is a Go duration string (e.g. `30m`, `1h`).

- `create` - (Optional) Timeout for create operations.
- `read`   - (Optional) Timeout for read operations.
- `update` - (Optional) Timeout for update operations.
- `delete` - (Optional) Timeout for delete operations.
DESCRIPTION
}
