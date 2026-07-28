resource "azurerm_resource_group" "shared" {
  name     = "rg-shared"
  location = "northeurope"
}

resource "azurerm_container_registry" "shared" {
  name                = "acrsorcerysorcery01"
  resource_group_name = azurerm_resource_group.shared.name
  location             = azurerm_resource_group.shared.location
  sku                   = "Basic"
  admin_enabled         = false
}

output "acr_login_server" {
  value = azurerm_container_registry.shared.login_server
}

output "acr_id" {
  value = azurerm_container_registry.shared.id
}
