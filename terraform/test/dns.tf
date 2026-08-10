resource "azurerm_private_dns_zone" "test_private" {
  name                = var.private_dns_zone_name
  resource_group_name = azurerm_resource_group.test.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "test_private" {
  name                  = "vnet-test-link"
  resource_group_name   = azurerm_resource_group.test.name
  private_dns_zone_name = azurerm_private_dns_zone.test_private.name
  virtual_network_id    = azurerm_virtual_network.test.id
}

resource "azurerm_user_assigned_identity" "external_dns" {
  name                = "id-test-external-dns"
  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location
}

resource "azurerm_federated_identity_credential" "external_dns" {
  name                = "fic-test-external-dns"
  resource_group_name = azurerm_resource_group.test.name
  parent_id           = azurerm_user_assigned_identity.external_dns.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.test.oidc_issuer_url
  subject             = "system:serviceaccount:external-dns:external-dns"
}

resource "azurerm_role_assignment" "external_dns_private_dns_contributor" {
  scope                = azurerm_private_dns_zone.test_private.id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.external_dns.principal_id
}

output "private_dns_zone_name" {
  value = azurerm_private_dns_zone.test_private.name
}

output "external_dns_identity_client_id" {
  value = azurerm_user_assigned_identity.external_dns.client_id
}

# Dedicated private DNS zone for app-level internal hostnames (e.g.
# ArgoCD's internal load balancer), on the real kirui.dev subdomain -
# separate from test_private above, which already serves a different,
# established purpose (External DNS auto-registers records there under
# its placeholder domain) and is left untouched here.
resource "azurerm_private_dns_zone" "internal_tooling" {
  name                = "test-private.kirui.dev"
  resource_group_name = azurerm_resource_group.test.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "internal_tooling" {
  name                  = "vnet-test-link"
  resource_group_name   = azurerm_resource_group.test.name
  private_dns_zone_name = azurerm_private_dns_zone.internal_tooling.name
  virtual_network_id    = azurerm_virtual_network.test.id
}

# 10.0.1.7 confirmed live via `kubectl get svc argocd-server -n argocd`
# (aks-test context) immediately before this was written.
resource "azurerm_private_dns_a_record" "argocd_internal" {
  name                = "argocd"
  zone_name           = azurerm_private_dns_zone.internal_tooling.name
  resource_group_name = azurerm_resource_group.test.name
  ttl                 = 300
  records             = ["10.0.1.7"]
}
