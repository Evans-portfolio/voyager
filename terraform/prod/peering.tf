# test's VNet ID is constructed rather than looked up via a data source so
# this stack can plan independently of whether terraform/test has been
# re-applied yet - Azure resource IDs are deterministic from
# subscription/RG/name, so no dependency on apply order either direction.
locals {
  test_vnet_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.test_resource_group_name}/providers/Microsoft.Network/virtualNetworks/${var.test_vnet_name}"
}

resource "azurerm_virtual_network_peering" "prod_to_test" {
  name                      = "peer-prod-to-test"
  resource_group_name       = azurerm_resource_group.prod.name
  virtual_network_name      = azurerm_virtual_network.prod.name
  remote_virtual_network_id = local.test_vnet_id

  # Allows the jumpbox (which lives in test's VNet) to reach prod's
  # resources. Paired with test's peer-test-to-prod object, which sets
  # allow_virtual_network_access = false in the opposite direction -
  # prod has no network-layer path back into test at all.
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
