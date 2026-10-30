# Default example

Two route tables of a hub-and-spoke network, each used by a subnet:

- the hub's `AzureFirewallSubnet` table: `0.0.0.0/0` to the Internet, and another region's hub supernet
  through that hub's firewall, with gateway route propagation on;
- a spoke's table: `0.0.0.0/0` to the hub firewall's address (the subnet's fifth, `10.100.0.4`), in the
  shape of the connectivity compositions' `spoke_default_routes`, with gateway route propagation off.

No firewall is deployed: the routes only name its address. Run it with `scripts/e2e.sh examples/default`:
apply, a second plan that must be empty, destroy.
