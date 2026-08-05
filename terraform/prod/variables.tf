variable "location" {
  description = "Azure region for the prod environment"
  type        = string
  default     = "swedencentral"
}

variable "vnet_address_space" {
  description = "CIDR for the prod VNet"
  type        = string
  default     = "10.1.0.0/16"
}

variable "aks_subnet_cidr" {
  description = "CIDR for the AKS node subnet"
  type        = string
  default     = "10.1.1.0/24"
}

variable "privatelink_subnet_cidr" {
  description = "CIDR for the Key Vault private endpoint subnet"
  type        = string
  default     = "10.1.3.0/28"
}

variable "postgres_subnet_cidr" {
  description = "CIDR for the delegated Postgres Flexible Server subnet"
  type        = string
  default     = "10.1.4.0/28"
}

variable "shared_jumpbox_subnet_cidr" {
  description = "CIDR of the test environment's jumpbox subnet (snet-test-jumpbox). This is the only remote range allowed through prod's NSGs - the jumpbox is shared with test rather than prod getting its own, to stay within the subscription's regional vCPU quota."
  type        = string
  default     = "10.0.2.0/28"
}

variable "test_resource_group_name" {
  description = "Resource group of the test environment, for cross-stack VNet peering"
  type        = string
  default     = "rg-test"
}

variable "test_vnet_name" {
  description = "Name of the test VNet, for cross-stack VNet peering"
  type        = string
  default     = "vnet-test"
}

variable "shared_jumpbox_name" {
  description = "Name of the shared jumpbox VM (lives in terraform/test), for cross-stack IAM and the Postgres/Key Vault secret relay"
  type        = string
  default     = "vm-test-jumpbox"
}

variable "keyvault_name" {
  description = "Globally-unique name for the prod Key Vault"
  type        = string
  default     = "kv-sorcery-prod01"
}

variable "terraform_sp_object_id" {
  description = "Object ID of the terraform-sp service principal (for self-granted Key Vault data-plane roles)"
  type        = string
  default     = "3a1d86f0-3183-412b-aab0-7dfb4c198ce5"
}

variable "postgres_sku_name" {
  description = "Postgres Flexible Server SKU (tier_size) - General Purpose D2s_v3. Burstable does not actually support ZoneRedundant HA despite the SKU-capability API listing it as supported; General Purpose is the smallest tier that genuinely does."
  type        = string
  default     = "GP_Standard_D2s_v3"
}

variable "postgres_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "16"
}

variable "postgres_storage_mb" {
  description = "Postgres storage in MB (32768 = 32 GiB, Azure minimum)"
  type        = number
  default     = 32768
}

variable "postgres_backup_retention_days" {
  description = "Backup/PITR retention window in days"
  type        = number
  default     = 30
}

variable "postgres_admin_username" {
  description = "Postgres Flexible Server admin login"
  type        = string
  default     = "pgadmin"
}

variable "kubernetes_version" {
  description = "AKS control plane and node pool version"
  type        = string
  default     = "1.35"
}

variable "main_node_vm_size" {
  description = "VM size for the main (system) node pool"
  type        = string
  default     = "Standard_B2as_v2"
}

variable "tools_node_vm_size" {
  description = "VM size for the tools node pool"
  type        = string
  default     = "Standard_B2as_v2"
}

variable "monitoring_node_vm_size" {
  description = "VM size for the monitoring node pool"
  type        = string
  default     = "Standard_B2as_v2"
}

variable "pod_cidr" {
  description = "Non-routable CIDR for Azure CNI Overlay pod IPs - distinct from test's to avoid any overlap"
  type        = string
  default     = "192.169.0.0/16"
}

variable "service_cidr" {
  description = "CIDR for Kubernetes service ClusterIPs - distinct from test's to avoid any overlap"
  type        = string
  default     = "172.17.0.0/16"
}

variable "dns_service_ip" {
  description = "IP within service_cidr for the cluster DNS service"
  type        = string
  default     = "172.17.0.10"
}

variable "acr_name" {
  description = "Name of the shared ACR to grant AcrPull against"
  type        = string
  default     = "acrsorcerysorcery01"
}

variable "acr_resource_group_name" {
  description = "Resource group of the shared ACR"
  type        = string
  default     = "rg-shared"
}

variable "test_aks_subnet_cidr" {
  description = "CIDR of test's AKS node subnet (snet-test-aks). ArgoCD runs as pods in test's cluster and needs direct network reachability to prod's private AKS API server - Azure CNI Overlay means pod traffic is SNATed to the underlying node's VNet IP before it ever reaches the peering link, so this is the real source range for that traffic, not a narrower pod CIDR."
  type        = string
  default     = "10.0.1.0/24"
}
