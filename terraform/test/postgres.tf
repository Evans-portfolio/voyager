resource "azurerm_subnet" "postgres" {
  name                 = "snet-test-postgres"
  resource_group_name  = azurerm_resource_group.test.name
  virtual_network_name = azurerm_virtual_network.test.name
  address_prefixes     = [var.postgres_subnet_cidr]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "fs"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.test.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "vnet-test-link"
  resource_group_name   = azurerm_resource_group.test.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.test.id
}

resource "random_password" "postgres_admin" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>:?"
}

resource "azurerm_postgresql_flexible_server" "test" {
  name                = "psql-test-sorcery"
  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location

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
  zone                   = "2"

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgres,
  ]
}

# Terraform (voyager) cannot reach the vaults data-plane endpoint - same
# network restriction as AKS/Postgres. Route the secret write through the
# jumpbox, which already has Key Vault Secrets Officer and VNet reachability.
# The command below only ever references a file path, never the secret
# value itself, so it never appears in Terraform's own console/log output.
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
      scp -i ~/.ssh/jumpbox_rsa -o StrictHostKeyChecking=accept-new         ${local_sensitive_file.postgres_admin_password.filename}         azureuser@${azurerm_public_ip.jumpbox.ip_address}:/tmp/pw.tmp
      ssh -i ~/.ssh/jumpbox_rsa azureuser@${azurerm_public_ip.jumpbox.ip_address}         'az login --identity -o none && az keyvault secret set --vault-name ${azurerm_key_vault.test.name} --name postgres-admin-password --value "$(cat /tmp/pw.tmp)" -o none && rm -f /tmp/pw.tmp'
      rm -f ${local_sensitive_file.postgres_admin_password.filename}
    EOT
  }

  depends_on = [
    azurerm_role_assignment.jumpbox_keyvault_secrets_officer,
    azurerm_postgresql_flexible_server.test,
  ]
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.test.fqdn
}
