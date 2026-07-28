output "resource_group_name" {
  value = azurerm_resource_group.test.name
}

output "vnet_id" {
  value = azurerm_virtual_network.test.id
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}
