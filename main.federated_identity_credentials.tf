module "federated_identity_credential" {
  source   = "./modules/federated_identity_credential"
  for_each = var.federated_identity_credentials

  name                = each.key
  parent_id           = azapi_resource.this.id
  issuer              = each.value.issuer
  subject             = each.value.subject
  audiences           = each.value.audiences
  ignore_body_changes = var.ignore_body_changes.managedidentity_user_assigned_identities_federated_identity_credentials
  resource_types      = var.resource_types.managedidentity_user_assigned_identities_federated_identity_credentials
  retry               = var.retry
  timeouts            = var.timeouts
}
