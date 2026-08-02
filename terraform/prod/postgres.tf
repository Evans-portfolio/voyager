# Unlike Key Vault's private endpoint, a Postgres Flexible Server's DNS
# zone cannot be pointed at a zone outside the server's own resource
# group - confirmed the hard way: Terraform reported the cross-RG update
# as applied, but the server's own metadata never actually changed, and
# it kept referencing rg-prod's zone even after that zone was deleted as
# part of the (wrong, for Postgres) consolidation attempt. Postgres keeps
# its own same-RG zone; only Key Vault consolidates onto test's shared
# zone. See the module-level note in the next block re: jumpbox
# resolution for this zone.
resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.prod.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "vnet-prod-link"
  resource_group_name   = azurerm_resource_group.prod.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.prod.id
}

resource "random_password" "postgres_admin" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>:?"
}

resource "azurerm_postgresql_flexible_server" "prod" {
  name                = "psql-prod-sorcery"
  resource_group_name = azurerm_resource_group.prod.name
  location            = azurerm_resource_group.prod.location

  sku_name                     = var.postgres_sku_name
  version                      = var.postgres_version
  storage_mb                   = var.postgres_storage_mb
  backup_retention_days        = var.postgres_backup_retention_days
  geo_redundant_backup_enabled = false

  delegated_subnet_id           = azurerm_subnet.postgres.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false

  administrator_login    = var.postgres_admin_username
  administrator_password = random_password.postgres_admin.result
  zone                   = "1"

  high_availability {
    mode                      = "ZoneRedundant"
    standby_availability_zone = "2"
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgres,
  ]
}

# Same rationale as terraform/test/postgres.tf: Terraform on voyager cannot
# reach the vaults data-plane endpoint, so the write happens via the shared
# jumpbox. The command Terraform logs only ever references a file path,
# never the password itself.
resource "local_sensitive_file" "postgres_admin_password" {
  content         = random_password.postgres_admin.result
  filename        = "${path.module}/.postgres-admin-password.tmp"
  file_permission = "0600"
}

resource "null_resource" "postgres_admin_password_kv" {
  triggers = {
    password_id = random_password.postgres_admin.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      scp -i ~/.ssh/jumpbox_rsa -o StrictHostKeyChecking=accept-new \
        ${local_sensitive_file.postgres_admin_password.filename} \
        azureuser@${data.azurerm_public_ip.shared_jumpbox.ip_address}:/tmp/pw-prod.tmp
      ssh -i ~/.ssh/jumpbox_rsa azureuser@${data.azurerm_public_ip.shared_jumpbox.ip_address} \
        'az login --identity -o none && az keyvault secret set --vault-name ${azurerm_key_vault.prod.name} --name postgres-admin-password --value "$(cat /tmp/pw-prod.tmp)" -o none && rm -f /tmp/pw-prod.tmp'
      rm -f ${local_sensitive_file.postgres_admin_password.filename}
    EOT
  }

  depends_on = [
    azurerm_role_assignment.jumpbox_keyvault_secrets_officer,
    azurerm_postgresql_flexible_server.prod,
  ]
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.prod.fqdn
}
