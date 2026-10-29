variable "location" {
  type        = string
  description = "Azure region of the user-assigned identity, for example `norwayeast`."
  nullable    = false
}

variable "name" {
  type        = string
  description = "Name of the user-assigned identity."
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]{2,127}$", var.name))
    error_message = "`name` must be 3 to 128 characters: letters, digits, hyphens and underscores, starting with a letter or digit."
  }
}

variable "parent_id" {
  type        = string
  description = "Resource ID of the resource group the user-assigned identity is created in."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a resource group resource ID."
  }
}

variable "federated_identity_credentials" {
  type = map(object({
    issuer    = string
    subject   = string
    audiences = optional(list(string), ["api://AzureADTokenExchange"])
  }))
  default     = {}
  description = <<DESCRIPTION
Federated identity credentials on the user-assigned identity, keyed by credential name (3 to 120 characters:
letters, digits, hyphens and underscores, starting with a letter or digit). Azure allows 20 per identity.

- `issuer` - URL of the external identity provider, for example `https://token.actions.githubusercontent.com`.
- `subject` - Identifier of the external workload, for example `repo:<owner>/<repo>:environment:<name>`.
- `audiences` - (Optional) Audiences accepted in the external token. Defaults to `["api://AzureADTokenExchange"]`.
DESCRIPTION
  nullable    = false

  validation {
    condition     = length(var.federated_identity_credentials) <= 20
    error_message = "A user-assigned identity holds at most 20 federated identity credentials."
  }
}

variable "isolation_scope" {
  type        = string
  default     = "None"
  description = "Regional restriction on assigning the identity: `None` (Azure's default) or `Regional`."
  nullable    = false

  validation {
    condition     = contains(["None", "Regional"], var.isolation_scope)
    error_message = "`isolation_scope` must be `None` or `Regional`."
  }
}

variable "lock" {
  type = object({
    kind  = string
    name  = optional(string, null)
    notes = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
Controls the Resource Lock configuration for this resource. The following properties can be specified:

- `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
- `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.
- `notes` - (Optional) Notes about the lock. This value maps to `Microsoft.Authorization/locks.properties.notes`.
DESCRIPTION

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be either `\"CanNotDelete\"` or `\"ReadOnly\"`."
  }
}

variable "role_assignments" {
  type = map(object({
    name                                   = optional(string, null)
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
A map of role assignments to create on the user-assigned identity. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the role assignment. If not set, a random UUID will be generated. Changing this forces the creation of a new resource.
- `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
- `principal_id` - The ID of the principal to assign the role to.
- `description` - (Optional) The description of the role assignment.
- `skip_service_principal_aad_check` - (Optional) If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
- `condition` - (Optional) The condition which will be used to scope the role assignment.
- `condition_version` - (Optional) The version of the condition syntax. Leave as `null` if you are not using a condition, if you are then valid values are '2.0'.
- `delegated_managed_identity_resource_id` - (Optional) The delegated Azure Resource Id which contains a Managed Identity. Changing this forces a new resource to be created. This field is only used in cross-tenant scenario.
- `principal_type` - (Optional) The type of the `principal_id`. Possible values are `User`, `Group` and `ServicePrincipal`. It is necessary to explicitly set this attribute when creating role assignments if the principal creating the assignment is constrained by ABAC rules that filters on the PrincipalType attribute.

> Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.
DESCRIPTION

  validation {
    condition = alltrue([
      for _, v in var.role_assignments :
      v.delegated_managed_identity_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", v.delegated_managed_identity_resource_id))
    ])
    error_message = "Each `role_assignments[*].delegated_managed_identity_resource_id` must be a valid user-assigned managed identity resource ID, or null."
  }
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the resource."
}
