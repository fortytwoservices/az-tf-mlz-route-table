mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-test"
      output = {
        properties = {
          clientId    = "22222222-2222-2222-2222-222222222222"
          principalId = "33333333-3333-3333-3333-333333333333"
          tenantId    = "44444444-4444-4444-4444-444444444444"
        }
      }
    }
  }
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [
          {
            id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
            role_name = "Reader"
          }
        ]
      }
    }
  }
}
mock_provider "random" {}
mock_provider "time" {}

variables {
  location  = "norwayeast"
  name      = "id-test"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
}

run "defaults" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30"
    error_message = "The identity should use the default resource type."
  }
  assert {
    condition     = azapi_resource.this.name == var.name && azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.location == var.location
    error_message = "The identity should be created with name, parent_id and location."
  }
  assert {
    condition     = azapi_resource.this.body.properties.isolationScope == "None"
    error_message = "isolationScope should be sent with Azure's default, so that changing it back reaches Azure."
  }
  assert {
    condition     = azapi_resource.this.retry == null
    error_message = "retry should be unset by default."
  }
  assert {
    condition     = azapi_resource.this.timeouts == null
    error_message = "timeouts should be unset by default."
  }
  assert {
    condition     = length(coalesce(azapi_resource.this.tags, {})) == 0 # computed: the mock returns {}
    error_message = "tags should be unset by default."
  }
  assert {
    condition     = module.interfaces.lock_resource_id == null && length(module.interfaces.role_assignment_resource_ids) + length(module.federated_identity_credential) == 0
    error_message = "No lock, role assignment or credential should be created by default."
  }
  assert {
    condition     = output.resource_id == azapi_resource.this.id && output.name == var.name
    error_message = "resource_id and name should come from the identity."
  }
  assert {
    condition     = output.principal_id == "33333333-3333-3333-3333-333333333333" && output.client_id == "22222222-2222-2222-2222-222222222222" && output.tenant_id == "44444444-4444-4444-4444-444444444444"
    error_message = "principal_id, client_id and tenant_id should come from the identity's exported properties."
  }
  assert {
    condition     = length(output.federated_identity_credential_resource_ids) == 0
    error_message = "No credential IDs should be output by default."
  }
}

run "identity_options" {
  command = apply

  variables {
    isolation_scope = "Regional"
    tags            = { environment = "test" }
  }

  assert {
    condition     = azapi_resource.this.body.properties.isolationScope == "Regional"
    error_message = "isolation_scope should map to properties.isolationScope."
  }
  assert {
    condition     = azapi_resource.this.tags == tomap({ environment = "test" })
    error_message = "tags should be set on the identity."
  }
}

run "federated_identity_credentials" {
  command = apply

  variables {
    federated_identity_credentials = {
      github-main = {
        issuer  = "https://token.actions.githubusercontent.com"
        subject = "repo:example/example:ref:refs/heads/main"
      }
      github-pr = {
        issuer    = "https://token.actions.githubusercontent.com"
        subject   = "repo:example/example:pull_request"
        audiences = ["api://custom"]
      }
    }
  }

  assert {
    condition     = toset(keys(module.federated_identity_credential)) == toset(["github-main", "github-pr"])
    error_message = "One credential module should be created per map entry."
  }
  assert {
    condition     = module.federated_identity_credential["github-main"].name == "github-main"
    error_message = "The map key should be the credential name."
  }
  assert {
    condition     = keys(output.federated_identity_credential_resource_ids) == ["github-main", "github-pr"]
    error_message = "Credential resource IDs should be output by credential name."
  }
}

run "interfaces" {
  command = apply

  variables {
    federated_identity_credentials = {
      github-main = {
        issuer  = "https://token.actions.githubusercontent.com"
        subject = "repo:example/example:ref:refs/heads/main"
      }
    }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      by_name = {
        role_definition_id_or_name = "Reader"
        principal_id               = "55555555-5555-5555-5555-555555555555"
      }
      tenant_level_id = {
        role_definition_id_or_name       = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        principal_id                     = "66666666-6666-6666-6666-666666666666"
        skip_service_principal_aad_check = true
      }
    }
  }

  # Their behaviour is tested in az-tf-mlz-interfaces; a test sees only its outputs.
  assert {
    condition     = module.interfaces.lock_resource_id != null && keys(module.interfaces.role_assignment_resource_ids) == ["by_name", "tenant_level_id"]
    error_message = "The lock and role assignments should be created through az-tf-mlz-interfaces."
  }
}

run "azapi_settings_reach_every_resource" {
  command = apply

  # ignore_body_changes is write-only, so a test cannot read it back, and avm_interface_ignore_body_changes
  # only checks that the argument uses the variable, not which slot. Setting it here proves the slots are
  # accepted; which resource reads which slot is left to review. The interface keys of resource_types and
  # ignore_body_changes, retry and timeouts go to az-tf-mlz-interfaces, whose tests check them.
  variables {
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = {
        role_definition_id_or_name = "Reader"
        principal_id               = "55555555-5555-5555-5555-555555555555"
      }
    }
    resource_types = {
      managedidentity_user_assigned_identities = "Microsoft.ManagedIdentity/userAssignedIdentities@2025-05-31-preview"
      authorization_locks                      = "Microsoft.Authorization/locks@2016-09-01"
      authorization_role_assignments           = "Microsoft.Authorization/roleAssignments@2020-04-01-preview"
    }
    ignore_body_changes = {
      managedidentity_user_assigned_identities = ["properties.isolationScope"]
      authorization_locks                      = ["properties.notes"]
      authorization_role_assignments           = ["properties.description"]
    }
    retry = {
      error_message_regex = ["AnotherOperationInProgress"]
    }
    timeouts = {
      create = "15m"
    }
  }

  assert {
    condition     = azapi_resource.this.type == "Microsoft.ManagedIdentity/userAssignedIdentities@2025-05-31-preview"
    error_message = "The resource_types override should reach the identity."
  }
  assert {
    condition     = azapi_resource.this.retry.error_message_regex == tolist(["AnotherOperationInProgress"]) && azapi_resource.this.timeouts.create == "15m"
    error_message = "retry and timeouts should reach the identity."
  }
}

run "invalid_name" {
  command = plan

  variables {
    name = "-bad"
  }

  expect_failures = [var.name]
}

run "invalid_parent_id" {
  command = plan

  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  }

  expect_failures = [var.parent_id]
}

run "invalid_isolation_scope" {
  command = plan

  variables {
    isolation_scope = "Global"
  }

  expect_failures = [var.isolation_scope]
}

run "empty_isolation_scope" {
  command = plan

  variables {
    isolation_scope = ""
  }

  expect_failures = [var.isolation_scope]
}

run "null_isolation_scope" {
  command = plan

  variables {
    isolation_scope = null
  }

  assert {
    condition     = azapi_resource.this.body.properties.isolationScope == "None"
    error_message = "A null isolation_scope should fall back to the default."
  }
}

run "invalid_lock_kind" {
  command = plan

  variables {
    lock = { kind = "Delete" }
  }

  expect_failures = [var.lock]
}

run "too_many_credentials" {
  command = plan

  variables {
    federated_identity_credentials = {
      for i in range(21) : "credential-${i}" => {
        issuer  = "https://token.actions.githubusercontent.com"
        subject = "repo:example/example:environment:env-${i}"
      }
    }
  }

  expect_failures = [var.federated_identity_credentials]
}

run "invalid_delegated_identity" {
  command = plan

  variables {
    role_assignments = {
      reader = {
        role_definition_id_or_name             = "Reader"
        principal_id                           = "55555555-5555-5555-5555-555555555555"
        delegated_managed_identity_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
      }
    }
  }

  expect_failures = [var.role_assignments]
}
