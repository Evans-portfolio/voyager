# prod's VNet ID is constructed rather than looked up via a data source so
# this stack can plan independently of whether terraform/prod has been
# applied yet - see terraform/prod/peering.tf for the mirrored rationale.
locals {
  prod_vnet_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.prod_resource_group_name}/providers/Microsoft.Network/virtualNetworks/${var.prod_vnet_name}"
}

resource "azurerm_virtual_network_peering" "test_to_prod" {
  name                      = "peer-test-to-prod"
  resource_group_name       = azurerm_resource_group.test.name
  virtual_network_name      = azurerm_virtual_network.test.name
  remote_virtual_network_id = local.prod_vnet_id

  # Blocks prod's resources from reaching back into test - the jumpbox
  # in test can reach prod (see prod's peer-prod-to-test object), but
  # nothing in prod can initiate a connection into test's VNet.
  allow_virtual_network_access = false

  # true (not the original false): Azure CNI Overlay requires IP forwarding
  # enabled on AKS node NICs so nodes can route their own pods' overlay
  # traffic. That same flag makes Azure treat traffic crossing this peering
  # from those nodes as "forwarded" traffic, which allow_forwarded_traffic
  # gates independently of NSGs - confirmed via a real timeout from a pod
  # on test's tools node pool to prod's AKS API (NSGs and DNS both verified
  # correct first) that resolved once this was flipped. The jumpbox never
  # needed this because its NIC has IP forwarding disabled, so its traffic
  # was never subject to this check.
  allow_forwarded_traffic = true
  allow_gateway_transit   = false
  use_remote_gateways     = false
}
