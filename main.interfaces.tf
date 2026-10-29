# A user-assigned identity has no diagnostic settings; a module whose resource has them also passes
# `diagnostic_settings`.
module "interfaces" {
  source = "git::https://github.com/fortytwoservices/az-tf-mlz-interfaces.git?ref=v0.1.0"

  resource_id = azapi_resource.this.id
  location    = var.location
  # Role definitions are looked up by name in the resource group, which exists before the identity, so
  # an unknown role name fails during plan.
  role_assignment_definition_scope = var.parent_id
  lock                             = var.lock
  role_assignments                 = var.role_assignments
  # Azure applies the lock to the credentials too, so it is removed around any change to them. Their
  # IDs would miss an update in place, which a ReadOnly lock also blocks: each submodule outputs a
  # `lock_dependency` that changes with its body (and its own `module.interfaces.lock_dependency`, if it
  # calls az-tf-mlz-interfaces).
  lock_dependencies   = { for name, credential in module.federated_identity_credential : name => credential.lock_dependency }
  resource_types      = var.resource_types # its interface keys are read
  ignore_body_changes = var.ignore_body_changes
  retry               = var.retry
  timeouts            = var.timeouts
}
