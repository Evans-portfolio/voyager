# Separate daily backup, distinct from Postgres Flexible Server's own
# built-in PITR (postgres.tf). PITR alone only protects against the
# server's own storage layer; this is a second, independent copy in a
# different service (Blob Storage) with its own retention, so a problem
# with the Postgres service itself (not just a bad write) still leaves a
# recoverable backup.

resource "azurerm_storage_account" "backup" {
  name                     = "stbackupprodsorcery01"
  resource_group_name      = azurerm_resource_group.prod.name
  location                 = azurerm_resource_group.prod.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # Not behind a private endpoint like the rest of prod's data-plane
  # resources - deliberately so, since a backup that depends on the same
  # private networking as the primary database is a weaker backup. Kept
  # narrow instead.
  #
  # Originally IP-rule-only (NAT gateway public IP + voyager's IP, for
  # Terraform itself managing the container/lifecycle policy). That
  # turned out unreliable for the actual pod traffic: identity and RBAC
  # were independently confirmed correct, the NAT gateway IP was
  # confirmed correct and unchanged, and it still failed with
  # AuthorizationFailure (the same error code Azure Storage uses for
  # network-rule denials, not just RBAC ones) even ~24h after being set -
  # past any real propagation window. Same-region traffic from a VNet
  # doesn't reliably present as the literal NAT egress IP to Storage's
  # firewall the way it does to plain internet endpoints. Added the VNet
  # subnet directly instead (via the new service endpoint on
  # snet-prod-aks in network.tf) - the Azure-recommended mechanism for
  # this exact case. IP rules kept alongside for voyager's Terraform
  # access, which is a genuinely separate, real internet egress path.
  network_rules {
    default_action = "Deny"
    ip_rules = [
      azurerm_public_ip.nat.ip_address,
      "65.109.11.230",
    ]
    virtual_network_subnet_ids = [azurerm_subnet.aks.id]
  }
}

resource "azurerm_storage_container" "backup" {
  name                  = "postgres-backups"
  storage_account_name  = azurerm_storage_account.backup.name
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "backup" {
  storage_account_id = azurerm_storage_account.backup.id

  rule {
    name    = "expire-old-backups"
    enabled = true
    filters {
      prefix_match = ["postgres-backups/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 30
      }
    }
  }
}

resource "azurerm_user_assigned_identity" "backup" {
  name                = "id-prod-backup"
  resource_group_name = azurerm_resource_group.prod.name
  location            = azurerm_resource_group.prod.location
}

resource "azurerm_federated_identity_credential" "backup" {
  name                = "fic-prod-backup"
  resource_group_name = azurerm_resource_group.prod.name
  parent_id           = azurerm_user_assigned_identity.backup.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.prod.oidc_issuer_url
  subject             = "system:serviceaccount:sample-app:postgres-backup"
}

resource "azurerm_role_assignment" "backup_storage_contributor" {
  scope                = azurerm_storage_account.backup.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.backup.principal_id
}

# Storage Blob Data Contributor alone is not enough - same lesson as the
# ACR purge task's identity: az storage blob upload-batch still resolves
# the account via ARM first even with --auth-mode login, which fails
# without ARM-level read access, surfacing as a misleading "blocked by
# network rules" error. Confirmed live before adding this.
resource "azurerm_role_assignment" "backup_storage_reader" {
  scope                = azurerm_storage_account.backup.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.backup.principal_id
}

output "backup_identity_client_id" {
  value = azurerm_user_assigned_identity.backup.client_id
}

output "backup_storage_account_name" {
  value = azurerm_storage_account.backup.name
}
