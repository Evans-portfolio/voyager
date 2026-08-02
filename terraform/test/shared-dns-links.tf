# prod's Key Vault private endpoint registers into this same zone instead
# of owning a separate one - a VNet can only be linked to one zone per
# privatelink namespace, and vnet-test already holds the link, so prod
# resolves through this rather than a second, same-named zone of its own.
#
# Postgres does NOT use this pattern - a Flexible Server's private DNS
# zone must live in the server's own resource group (confirmed via a
# failed cross-RG repoint attempt), so prod keeps its own
# privatelink.postgres.database.azure.com zone in rg-prod. That means
# vnet-test can't also link to it (same one-zone-per-name rule, and
# vnet-test already owns that name via test's own zone) - the jumpbox
# cannot get automatic DNS resolution for prod's Postgres FQDN. See
# terraform/prod/postgres.tf for the fuller note.
resource "azurerm_private_dns_zone_virtual_network_link" "vault_prod" {
  name                  = "vnet-prod-link"
  resource_group_name   = azurerm_resource_group.test.name
  private_dns_zone_name = azurerm_private_dns_zone.vault.name
  virtual_network_id    = local.prod_vnet_id
}

# Deliberately NOT adding a postgres_prod link here (test's postgres zone ->
# vnet-prod), matching the vault_prod pattern above. Confirmed twice, live,
# via terraform apply: Azure rejects it with "A virtual network cannot be
# linked to multiple zones with overlapping namespaces" - vnet-prod is
# already linked to prod's OWN privatelink.postgres.database.azure.com zone
# (rg-prod, required because Postgres Flexible Server's DNS zone must live
# in the server's own resource group), so a second link to test's
# same-named zone is a hard Azure platform rejection, not a config gap.
# There is no resource block that fixes this - don't re-add one.
#
# Net effect: the jumpbox can't resolve prod's Postgres FQDN via DNS. This
# is an accepted limitation of the shared-jumpbox architecture; use the
# server's IP directly for jumpbox-side admin access. The path that
# actually matters - prod's own AKS pods resolving prod's own Postgres via
# vnet-prod's link to its own zone - is unaffected.
