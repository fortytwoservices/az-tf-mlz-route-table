#!/usr/bin/env bash
# The checks CI runs, for the root module, every modules/* and every examples/*: format, validate,
# lint, unit tests and README drift. Needs terraform, tflint and terraform-docs.
#   scripts/check.sh         check only (CI)
#   scripts/check.sh --fix   format the code and regenerate the READMEs, then check the rest
set -euo pipefail
cd "$(dirname "$0")/.."
root=$PWD
fix=false
[[ ${1:-} == --fix ]] && fix=true

shopt -s nullglob
modules=(. modules/*)
examples=(examples/*)

step() { printf '\n== %s\n' "$*"; }

step fmt
if $fix; then terraform fmt -recursive; else terraform fmt -check -recursive; fi

for dir in "${modules[@]}" "${examples[@]}"; do
  step "validate $dir"
  # The unit tests' directory too, or helper modules called from tests/unit are "not installed" (it works
  # for directories without tests).
  terraform -chdir="$dir" init -backend=false -input=false -test-directory=tests/unit >/dev/null
  terraform -chdir="$dir" validate -no-color
done

step "tflint plugins"
tflint --init --config="$root/.tflint.hcl"
tflint --init --config="$root/examples/.tflint.hcl"
# Lint from inside each directory: with --chdir or --recursive, avm_terraform_configuration_file_required
# does not find a submodule's terraform.tf (tflint 0.65.0, tflint-ruleset-avm 1.4.0).
for dir in "${modules[@]}"; do
  step "tflint $dir"
  (cd "$dir" && tflint --config="$root/.tflint.hcl")
done
for dir in "${examples[@]}"; do
  step "tflint $dir"
  (cd "$dir" && tflint --config="$root/examples/.tflint.hcl")
done

for dir in "${modules[@]}"; do
  step "unit tests $dir"
  terraform -chdir="$dir" test -test-directory=tests/unit -no-color
done

for dir in "${modules[@]}" "${examples[@]}"; do
  step "README $dir"
  if $fix; then
    terraform-docs --config="$root/.terraform-docs.yml" "$dir"
  else
    terraform-docs --config="$root/.terraform-docs.yml" --output-check "$dir"
  fi
done
