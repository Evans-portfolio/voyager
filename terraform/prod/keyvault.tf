resource "azurerm_key_vault" "prod" {
  name                = var.keyvault_name
  resource_group_name = azurerm_resource_group.prod.name
  location            = azurerm_resource_group.prod.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  enable_rbac_authorization     = true
  public_network_access_enabled = false
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
}

# Key Vault's private DNS zone name (privatelink.vaultcore.azure.net) is
# fixed by Azure, not per-environment - a VNet can only link to one zone
# per name, and vnet-test already owns the link for this one. Prod's
# private endpoint registers into test's existing zone instead of a
# second, same-named zone of its own. See terraform/test/shared-dns-links.tf
# for the vnet-prod link added to that zone.
locals {
  test_vault_dns_zone_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.test_resource_group_name}/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
}

resource "azurerm_private_endpoint" "vault" {
  name                = "pe-prod-keyvault"
  resource_group_name = azurerm_resource_group.prod.name
  location            = azurerm_resource_group.prod.location
  subnet_id           = azurerm_subnet.privatelink.id

  private_service_connection {
    name                           = "psc-prod-keyvault"
    private_connection_resource_id = azurerm_key_vault.prod.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [local.test_vault_dns_zone_id]
  }
}

resource "azurerm_role_assignment" "terraform_sp_keyvault_secrets_officer" {
  scope                = azurerm_key_vault.prod.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.terraform_sp_object_id
}

# --- Shared jumpbox (lives in terraform/test, not this stack) ---

data "azurerm_virtual_machine" "shared_jumpbox" {
  name                = var.shared_jumpbox_name
  resource_group_name = var.test_resource_group_name
}

data "azurerm_public_ip" "shared_jumpbox" {
  name                = "pip-test-jumpbox"
  resource_group_name = var.test_resource_group_name
}

# Grants the jumpbox write access to prod's Key Vault - Officer, not User,
# because postgres.tf's password relay runs `az keyvault secret set` from
# the jumpbox (same reasoning as test's jumpbox_keyvault_secrets_officer).
# This is one of the two IAM role assignments planned for the later IAM
# stage; it's included now because Postgres's own provisioning depends on
# it to finish, not as a shortcut around that stage. The AKS-scoped
# assignment (jumpbox -> aks-prod) stays deferred until aks-prod exists.
resource "azurerm_role_assignment" "jumpbox_keyvault_secrets_officer" {
  scope                = azurerm_key_vault.prod.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_virtual_machine.shared_jumpbox.identity[0].principal_id
}

output "keyvault_uri" {
  value = azurerm_key_vault.prod.vault_uri
}

# Workload identity for the External Secrets Operator running inside
# aks-prod - same pattern as terraform/test/keyvault.tf's id-test-eso,
# scoped to prod's own Key Vault and prod's own OIDC issuer. Needed so
# prod's ArgoCD-managed ExternalSecret (postgres-credentials) can pull
# postgres-admin-password from kv-sorcery-prod01 without cross-VNet
# traffic - ESO runs inside aks-prod itself and talks to prod's Key
# Vault over its own private endpoint.
resource "azurerm_user_assigned_identity" "eso" {
  name                = "id-prod-eso"
  resource_group_name = azurerm_resource_group.prod.name
  location            = azurerm_resource_group.prod.location
}

resource "azurerm_federated_identity_credential" "eso" {
  name                = "fic-prod-eso"
  resource_group_name = azurerm_resource_group.prod.name
  parent_id           = azurerm_user_assigned_identity.eso.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.prod.oidc_issuer_url
  subject             = "system:serviceaccount:external-secrets:external-secrets"
}

resource "azurerm_role_assignment" "eso_keyvault_secrets_user" {
  scope                = azurerm_key_vault.prod.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.eso.principal_id
}

output "eso_identity_client_id" {
  value = azurerm_user_assigned_identity.eso.client_id
}
