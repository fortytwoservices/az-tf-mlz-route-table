# az-tf-mlz-template

The template for Fortytwo's managed landing zone (MLZ) Terraform modules, `az-tf-mlz-<name>`: AzAPI
only, shaped like the Azure Verified Modules (AVM) AzAPI modules, without telemetry.

## Start a module from this template

1. Create the repository from the template and apply the repository settings:

   ```sh
   gh repo create fortytwoservices/az-tf-mlz-<name> --internal --template fortytwoservices/az-tf-mlz-template --clone
   cd az-tf-mlz-<name>
   scripts/repo-settings.sh fortytwoservices/az-tf-mlz-<name>
   ```

   CI reads the internal `az-tf-mlz-*` modules with the reader App `gh-az-tf-modules-reader`: set its
   private key as the secret `AZ_TF_MODULE_READER_PRIVATE_KEY` (the script prints the command when it is
   missing). If other modules will call this one, an org owner also adds the repository to the App's
   selected repositories (organization settings, GitHub Apps, `gh-az-tf-modules-reader`, Configure).

2. On a branch, replace the placeholder module (below) with the real one: root files, `modules/*`,
   `examples/*` and the tests. Rewrite this `_header.md`; keep `_footer.md`. Delete `CHANGELOG.md` and
   set `.release-please-manifest.json` to `{}`: both carry the template's own releases, and left in place
   they make the module's first release something other than 0.1.0.
3. Run `scripts/check.sh --fix`, then the Azure tests, and open a pull request whose title starts with
   `feat:`. Merging it makes release-please open the release pull request for the first version.

## The placeholder module

A user-assigned identity with federated identity credentials. It is here to keep every pattern a
module needs working and tested:

- the primary resource `azapi_resource.this`, with `resource_types`, `ignore_body_changes`, `retry`,
  `timeouts` and `tags`;
- a child resource type as a submodule managing one instance (`modules/federated_identity_credential`),
  called with `for_each` by the root, with its writes serialised on the parent (`locks`);
- the lock and role assignment interfaces through
  [`az-tf-mlz-interfaces`](https://github.com/fortytwoservices/az-tf-mlz-interfaces), with the
  credentials passed as `lock_dependencies` so the lock is removed around their changes;
- unit tests with mocked providers, integration tests in Azure, and an example that is applied,
  planned again (no changes allowed) and destroyed.
