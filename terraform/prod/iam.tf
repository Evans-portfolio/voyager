data "azurerm_container_registry" "shared" {
  name                = var.acr_name
  resource_group_name = var.acr_resource_group_name
}

resource "azurerm_role_assignment" "aks_network" {
  scope                = azurerm_subnet.aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.prod.identity[0].principal_id
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = data.azurerm_container_registry.shared.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.prod.kubelet_identity[0].object_id
}

# Jumpbox -> aks-prod access. Drafted earlier when aks-prod didn't exist yet
# (couldn't be applied without a scope target); now real.
resource "azurerm_role_assignment" "jumpbox_aks_user_prod" {
  scope                = azurerm_kubernetes_cluster.prod.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = data.azurerm_virtual_machine.shared_jumpbox.identity[0].principal_id
}
