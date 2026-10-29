# Default example

A resource group, then a user-assigned identity with two federated identity credentials for GitHub
Actions. The two credentials are written one after the other, as Azure requires.

Run it with `scripts/e2e.sh examples/default`: apply, a second plan that must be empty, destroy.
