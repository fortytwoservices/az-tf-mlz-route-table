output "principal_id" {
  description = "Object ID of the identity's service principal."
  value       = module.user_assigned_identity.principal_id
}

output "resource_id" {
  description = "Resource ID of the user-assigned identity."
  value       = module.user_assigned_identity.resource_id
}
