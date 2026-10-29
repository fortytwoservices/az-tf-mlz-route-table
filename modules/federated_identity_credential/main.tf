resource "azapi_resource" "this" {
  type      = var.resource_types.managedidentity_user_assigned_identities_federated_identity_credentials
  name      = var.name
  parent_id = var.parent_id
  body = {
    properties = {
      audiences = var.audiences
      issuer    = var.issuer
      subject   = var.subject
    }
  }
  ignore_body_changes = length(var.ignore_body_changes.managedidentity_user_assigned_identities_federated_identity_credentials) > 0 ? var.ignore_body_changes.managedidentity_user_assigned_identities_federated_identity_credentials : null
  # Azure rejects parallel writes of credentials under one identity with 409 Conflict (Microsoft Learn,
  # "Important considerations and restrictions for federated identity credentials").
  locks                  = [var.parent_id]
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}
