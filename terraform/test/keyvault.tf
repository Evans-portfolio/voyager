data "azurerm_client_config" "current" {}

resource "azurerm_subnet" "privatelink" {
  name                 = "snet-test-privatelink"
  resource_group_name  = azurerm_resource_group.test.name
  virtual_network_name = azurerm_virtual_network.test.name
  address_prefixes     = [var.privatelink_subnet_cidr]

  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_key_vault" "test" {
  name                = var.keyvault_name
  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  enable_rbac_authorization     = true
  public_network_access_enabled = false
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
}

resource "azurerm_private_dns_zone" "vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.test.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "vault" {
  name                  = "vnet-test-link"
  resource_group_name   = azurerm_resource_group.test.name
  private_dns_zone_name = azurerm_private_dns_zone.vault.name
  virtual_network_id    = azurerm_virtual_network.test.id
}

resource "azurerm_private_endpoint" "vault" {
  name                = "pe-test-keyvault"
  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location
  subnet_id           = azurerm_subnet.privatelink.id

  private_service_connection {
    name                           = "psc-test-keyvault"
    private_connection_resource_id = azurerm_key_vault.test.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.vault.id]
  }
}

resource "azurerm_user_assigned_identity" "eso" {
  name                = "id-test-eso"
  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location
}

resource "azurerm_federated_identity_credential" "eso" {
  name                = "fic-test-eso"
  resource_group_name = azurerm_resource_group.test.name
  parent_id           = azurerm_user_assigned_identity.eso.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.test.oidc_issuer_url
  subject             = "system:serviceaccount:external-secrets:external-secrets"
}

resource "azurerm_role_assignment" "eso_keyvault_secrets_user" {
  scope                = azurerm_key_vault.test.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.eso.principal_id
}

output "keyvault_uri" {
  value = azurerm_key_vault.test.vault_uri
}

output "eso_identity_client_id" {
  value = azurerm_user_assigned_identity.eso.client_id
}
