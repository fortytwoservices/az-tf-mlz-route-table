variable "issuer" {
  type        = string
  description = "URL of the external identity provider, for example `https://token.actions.githubusercontent.com`."
  nullable    = false
}

variable "name" {
  type        = string
  description = "Name of the federated identity credential. Cannot be changed after creation."
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]{2,119}$", var.name))
    error_message = "`name` must be 3 to 120 characters: letters, digits, hyphens and underscores, starting with a letter or digit."
  }
}

variable "parent_id" {
  type        = string
  description = "Resource ID of the user-assigned identity that holds the credential."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", var.parent_id))
    error_message = "`parent_id` must be a user-assigned identity resource ID."
  }
}

variable "subject" {
  type        = string
  description = "Identifier of the external workload, for example `repo:<owner>/<repo>:environment:<name>`."
  nullable    = false
}

variable "audiences" {
  type        = list(string)
  default     = ["api://AzureADTokenExchange"]
  description = "Audiences accepted in the external token. Azure accepts exactly one."
  nullable    = false

  validation {
    condition     = length(var.audiences) == 1
    error_message = "`audiences` must hold exactly one audience."
  }
}
