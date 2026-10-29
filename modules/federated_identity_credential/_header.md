# Federated identity credential

One federated identity credential on a user-assigned identity
(`Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials`). The root module
calls it once per credential; it can also be called alone with the identity's resource ID.

Azure rejects parallel writes of credentials under one identity (409 Conflict), so every write locks
the parent identity's ID and credentials are written one at a time.
