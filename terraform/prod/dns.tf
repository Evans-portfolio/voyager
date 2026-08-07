# kirui.dev is a shared, publicly-registered domain - the zone itself was
# created directly in rg-shared (az network dns zone create), consistent
# with other shared resources (ACR, Terraform state), not owned by this
# stack. This is a data source, not a resource, for the same reason
# terraform/prod/iam.tf references the shared ACR by data source.
data "azurerm_dns_zone" "public" {
  name                = var.public_dns_zone_name
  resource_group_name = var.public_dns_zone_resource_group_name
}

resource "azurerm_user_assigned_identity" "external_dns" {
  name                = "id-prod-external-dns"
  resource_group_name = azurerm_resource_group.prod.name
  location            = azurerm_resource_group.prod.location
}

resource "azurerm_federated_identity_credential" "external_dns" {
  name                = "fic-prod-external-dns"
  resource_group_name = azurerm_resource_group.prod.name
  parent_id           = azurerm_user_assigned_identity.external_dns.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.prod.oidc_issuer_url
  subject             = "system:serviceaccount:external-dns:external-dns"
}

# "DNS Zone Contributor", not "Private DNS Zone Contributor" - kirui.dev is
# a public zone (test's equivalent role only applies to private zones).
resource "azurerm_role_assignment" "external_dns_public_dns_contributor" {
  scope                = data.azurerm_dns_zone.public.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.external_dns.principal_id
}

output "external_dns_identity_client_id" {
  value = azurerm_user_assigned_identity.external_dns.client_id
}

resource "azurerm_user_assigned_identity" "cert_manager" {
  name                = "id-prod-cert-manager"
  resource_group_name = azurerm_resource_group.prod.name
  location            = azurerm_resource_group.prod.location
}

resource "azurerm_federated_identity_credential" "cert_manager" {
  name                = "fic-prod-cert-manager"
  resource_group_name = azurerm_resource_group.prod.name
  parent_id           = azurerm_user_assigned_identity.cert_manager.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.prod.oidc_issuer_url
  subject             = "system:serviceaccount:cert-manager:cert-manager"
}

resource "azurerm_role_assignment" "cert_manager_public_dns_contributor" {
  scope                = data.azurerm_dns_zone.public.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.cert_manager.principal_id
}

output "cert_manager_identity_client_id" {
  value = azurerm_user_assigned_identity.cert_manager.client_id
}
