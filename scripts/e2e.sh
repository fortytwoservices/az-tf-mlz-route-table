#!/usr/bin/env bash
# End-to-end run of every example (or the examples given): apply, a second plan that must show no
# changes, destroy. The example is destroyed whether or not a step fails.
#   ARM_SUBSCRIPTION_ID=<test subscription> scripts/e2e.sh [examples/<name> ...]
set -euo pipefail
cd "$(dirname "$0")/.."
: "${ARM_SUBSCRIPTION_ID:?set ARM_SUBSCRIPTION_ID to the test subscription}"

shopt -s nullglob
dirs=("$@")
[[ ${#dirs[@]} -gt 0 ]] || dirs=(examples/*)

for dir in "${dirs[@]}"; do
  printf '\n== e2e %s\n' "$dir"
  terraform -chdir="$dir" init -input=false >/dev/null
  trap 'terraform -chdir="$dir" destroy -auto-approve -input=false -no-color' EXIT
  terraform -chdir="$dir" apply -auto-approve -input=false -no-color
  # Exit code 2 means the second plan has changes: an idempotency failure, never retried away.
  terraform -chdir="$dir" plan -detailed-exitcode -input=false -no-color
  terraform -chdir="$dir" destroy -auto-approve -input=false -no-color
  trap - EXIT
done
