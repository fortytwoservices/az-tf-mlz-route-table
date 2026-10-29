# Lint config for every examples/* directory. scripts/check.sh passes this file explicitly.
# Examples are root configurations that call the module, so module-only rules are off.

plugin "terraform" {
  enabled = true
  preset  = "all"
  version = "0.15.0"
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"
}

plugin "avm" {
  enabled   = true
  version   = "1.4.0"
  source    = "github.com/Azure/tflint-ruleset-avm"
  signature = "attestation"
}

rule "terraform_standard_module_structure" {
  enabled = false # same file layout as the module
}

rule "avm_provider_modtm_version_constraint" {
  enabled = false # no telemetry by decision, so no modtm provider
}

rule "avm_terraform_module_source_required" {
  enabled = false # examples call the module as ../../
}

rule "avm_terraform_provider_block_disallowed" {
  enabled = false # an example is a root configuration and configures its provider
}

# The interface variables are module inputs; an example only passes them.
rule "avm_interface_ignore_body_changes" {
  enabled = false
}

rule "avm_interface_resource_types" {
  enabled = false
}

rule "avm_interface_retry" {
  enabled = false
}

rule "avm_interface_timeouts" {
  enabled = false
}

rule "avm_output_resource_id_required" {
  enabled = false # an example's outputs are whatever it demonstrates
}
