#!/usr/bin/env bash
# Integration tests against real Azure, for the root module and every modules/* (or the directories
# given). Resources are created in a test resource group and destroyed by the test.
#   ARM_SUBSCRIPTION_ID=<test subscription> scripts/integration.sh [dir ...]
set -euo pipefail
cd "$(dirname "$0")/.."
: "${ARM_SUBSCRIPTION_ID:?set ARM_SUBSCRIPTION_ID to the test subscription}"

shopt -s nullglob
dirs=("$@")
[[ ${#dirs[@]} -gt 0 ]] || dirs=(. modules/*)

for dir in "${dirs[@]}"; do
  printf '\n== integration tests %s\n' "$dir"
  # The test directory must be named, or init skips the helper modules the tests call.
  terraform -chdir="$dir" init -backend=false -input=false -test-directory=tests/integration >/dev/null
  terraform -chdir="$dir" test -test-directory=tests/integration -no-color
done
