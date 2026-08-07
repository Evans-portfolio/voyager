# prod's Key Vault private endpoint used to register into this zone
# instead of owning a separate one, on the assumption that a same-named
# zone could only exist once per subscription. That assumption was wrong -
# the real Azure constraint (confirmed live, see the postgres_prod note
# below) is narrower: a single VNet cannot be linked to two zones that
# share a name at the same time. Nothing stops each VNet from linking to
# its own same-named zone, which is exactly what Postgres already does
# (terraform/prod/postgres.tf owns privatelink.postgres.database.azure.com
# in rg-prod, linked only to vnet-prod). Key Vault now follows the same
# pattern - see terraform/prod/keyvault.tf. This link (vnet-prod -> test's
# zone) was removed as part of that fix; do not re-add it.

# Deliberately NOT adding a postgres_prod link here (test's postgres zone ->
# vnet-prod), same reasoning that motivated moving vault to its own
# per-environment zone above. Confirmed twice, live, via terraform apply:
# Azure rejects it with "A virtual network cannot be linked to multiple
# zones with overlapping namespaces" - vnet-prod is already linked to
# prod's OWN privatelink.postgres.database.azure.com zone (rg-prod,
# required because Postgres Flexible Server's DNS zone must live in the
# server's own resource group), so a second link to test's same-named
# zone is a hard Azure platform rejection, not a config gap. There is no
# resource block that fixes this - don't re-add one.
#
# Net effect: the jumpbox can't resolve prod's Postgres FQDN via DNS. This
# is an accepted limitation of the shared-jumpbox architecture; use the
# server's IP directly for jumpbox-side admin access. The path that
# actually matters - prod's own AKS pods resolving prod's own Postgres via
# vnet-prod's link to its own zone - is unaffected.
