#!/usr/bin/env bash
# Applies the MLZ repository settings to a module repository, and can be re-run:
# - squash merge only; the commit is the pull request title and description, so Conventional Commit
#   titles and footers (BREAKING CHANGE:, Release-As:) reach release-please; branches deleted on merge;
# - ruleset "main": changes through pull requests only, with the `check` and `pr-title` checks passing
#   and review threads resolved; no force pushes or deletion;
# - ruleset "release-tags": v* tags cannot be moved or deleted;
# - GITHUB_TOKEN read-only unless a workflow asks for more, and allowed to open pull requests
#   (release-please);
# - the client ID of the reader App CI uses for the internal az-tf-mlz-* modules (gh-az-tf-modules-reader).
#   Its private key is a secret, so the script only says when it is missing.
#   scripts/repo-settings.sh fortytwoservices/az-tf-mlz-<name>
set -euo pipefail
repo=${1:?usage: scripts/repo-settings.sh <owner>/<repository>}

gh api --method PATCH "repos/$repo" --silent \
  -F allow_squash_merge=true -F allow_merge_commit=false -F allow_rebase_merge=false \
  -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY \
  -F delete_branch_on_merge=true

gh api --method PUT "repos/$repo/actions/permissions/workflow" --silent \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true

# Creates the ruleset, or replaces the one with the same name.
ruleset() {
  local name=$1 body=$2 id
  id=$(gh api "repos/$repo/rulesets" --jq ".[] | select(.name == \"$name\") | .id")
  if [[ -n $id ]]; then
    gh api --method PUT "repos/$repo/rulesets/$id" --input - --silent <<<"$body"
  else
    gh api --method POST "repos/$repo/rulesets" --input - --silent <<<"$body"
  fi
  echo "ruleset $name applied"
}

ruleset main '{
  "name": "main",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["squash"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "required_status_checks": [{ "context": "check" }, { "context": "pr-title" }]
      }
    }
  ]
}'

ruleset release-tags '{
  "name": "release-tags",
  "target": "tag",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/tags/v*"], "exclude": [] } },
  "rules": [{ "type": "update" }, { "type": "deletion" }]
}'

gh variable set AZ_TF_MODULE_READER_CLIENT_ID --repo "$repo" --body Iv23lij4zkFanu3eweNo
if ! gh secret list --repo "$repo" --json name --jq '.[].name' | grep -qx AZ_TF_MODULE_READER_PRIVATE_KEY; then
  echo "missing secret: gh secret set AZ_TF_MODULE_READER_PRIVATE_KEY --repo $repo < <reader App private key>"
fi
