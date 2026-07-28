output "resource_group_name" {
  value = azurerm_resource_group.test.name
}

output "vnet_id" {
  value = azurerm_virtual_network.test.id
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.test.name
}

output "aks_kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.test.kubelet_identity[0].object_id
}
