# AKS auto-creates its own private DNS zone for a private cluster (unlike
# Key Vault/Postgres's fixed, shared zone names, this one is scoped to the
# cluster's own random suffix, so there's no overlapping-namespace conflict
# with anything already linked to vnet-test - a straightforward second link
# is all that's needed for the jumpbox to resolve it).
locals {
  aks_prod_private_dns_zone_name = trimprefix(
    azurerm_kubernetes_cluster.prod.private_fqdn,
    "${split(".", azurerm_kubernetes_cluster.prod.private_fqdn)[0]}."
  )
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks_prod_vnet_test" {
  name                  = "vnet-test-link"
  resource_group_name   = azurerm_kubernetes_cluster.prod.node_resource_group
  private_dns_zone_name = local.aks_prod_private_dns_zone_name
  virtual_network_id    = local.test_vnet_id
}
