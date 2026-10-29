mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-test/federatedIdentityCredentials/github-main"
    }
  }
}

variables {
  name      = "github-main"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-test"
  issuer    = "https://token.actions.githubusercontent.com"
  subject   = "repo:example/example:ref:refs/heads/main"
}

run "defaults" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2024-11-30"
    error_message = "The credential should use the default resource type."
  }
  assert {
    condition     = azapi_resource.this.name == var.name && azapi_resource.this.parent_id == var.parent_id
    error_message = "The credential should be created with name and parent_id."
  }
  assert {
    condition     = azapi_resource.this.body.properties.issuer == var.issuer && azapi_resource.this.body.properties.subject == var.subject && azapi_resource.this.body.properties.audiences == tolist(["api://AzureADTokenExchange"])
    error_message = "issuer, subject and the default audience should map to the request body."
  }
  assert {
    condition     = azapi_resource.this.locks == tolist([var.parent_id])
    error_message = "Writes should be serialised on the parent identity."
  }
  assert {
    condition     = azapi_resource.this.retry == null && azapi_resource.this.timeouts == null
    error_message = "retry and timeouts should be unset by default."
  }
  assert {
    condition     = output.resource_id == azapi_resource.this.id && output.name == var.name
    error_message = "resource_id and name should come from the credential."
  }
}

run "overrides" {
  command = apply

  variables {
    audiences           = ["api://custom"]
    resource_types      = { managedidentity_user_assigned_identities_federated_identity_credentials = "Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31" }
    ignore_body_changes = { managedidentity_user_assigned_identities_federated_identity_credentials = ["properties.subject"] }
    retry               = { error_message_regex = ["Conflict"] }
    timeouts            = { create = "10m" }
  }

  assert {
    condition     = azapi_resource.this.type == "Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31"
    error_message = "resource_types should override the API version."
  }
  assert {
    condition     = azapi_resource.this.body.properties.audiences == tolist(["api://custom"])
    error_message = "audiences should reach the request body."
  }
  assert {
    condition     = azapi_resource.this.retry.error_message_regex == tolist(["Conflict"]) && azapi_resource.this.timeouts.create == "10m"
    error_message = "retry and timeouts should reach the credential."
  }
}

run "subject_changed" {
  command = apply

  variables {
    subject = "repo:example/example:environment:production"
  }

  # An update in place keeps the ID, and a parent's ReadOnly lock blocks it too.
  assert {
    condition     = output.resource_id == run.defaults.resource_id && output.lock_dependency != run.defaults.lock_dependency && length(output.lock_dependency) == 64
    error_message = "lock_dependency should change with the body, not only with the ID, so the parent's lock is removed around an update."
  }
}

run "invalid_name" {
  command = plan

  variables {
    name = "ab"
  }

  expect_failures = [var.name]
}

run "invalid_parent_id" {
  command = plan

  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  }

  expect_failures = [var.parent_id]
}

run "two_audiences" {
  command = plan

  variables {
    audiences = ["api://one", "api://two"]
  }

  expect_failures = [var.audiences]
}
