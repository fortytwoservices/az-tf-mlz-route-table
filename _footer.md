## Development

Tools: Terraform 1.17.0, TFLint 0.65.0, terraform-docs 0.24.0 (the versions CI uses).

| What | Command |
|---|---|
| Format, validate, lint, unit tests, README drift (what CI runs) | `scripts/check.sh` |
| Format the code and regenerate the READMEs first | `scripts/check.sh --fix` |
| Integration tests in Azure | `ARM_SUBSCRIPTION_ID=<test subscription> scripts/integration.sh [dir ...]` |
| Examples: apply, plan again (must be empty), destroy | `ARM_SUBSCRIPTION_ID=<test subscription> scripts/e2e.sh [examples/<name> ...]` |

`README.md` files are generated from `_header.md`, the code and `_footer.md`; do not edit them by hand.

## Versions and releases

Every release is a SemVer tag `vX.Y.Z`; tags never move, and `main` is never consumed. Pin a release:

```hcl
source = "git::https://github.com/fortytwoservices/<repository>.git?ref=vX.Y.Z"
```

Pull requests are squash-merged, and their titles follow Conventional Commits, which set the next
version: `fix:` a patch, `feat:` a minor (a patch before 1.0.0), `feat!:` or `fix!:` a major (a minor
before 1.0.0). `docs:`, `test:`, `ci:`, `chore:` and `refactor:` release nothing. release-please keeps a
release pull request open; merging it writes `CHANGELOG.md`, the tag and the GitHub release.
