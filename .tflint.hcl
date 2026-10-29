# Lint config for the root module and every modules/* directory. Examples use examples/.tflint.hcl.
# scripts/check.sh passes this file explicitly, because TFLint loads no parent config per directory.

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
  enabled = false # main.<topic>.tf and variables.<topic>.tf splits are allowed
}

rule "avm_provider_modtm_version_constraint" {
  enabled = false # no telemetry by decision, so no modtm provider
}

rule "avm_terraform_module_source_required" {
  enabled = false # MLZ modules call each other through git sources; examples use ../../
}
