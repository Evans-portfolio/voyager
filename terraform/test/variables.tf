variable "location" {
  description = "Azure region for the test environment"
  type        = string
  default     = "swedencentral"
}

variable "vnet_address_space" {
  description = "CIDR for the test VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_cidr" {
  description = "CIDR for the AKS node subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "kubernetes_version" {
  description = "AKS control plane and node pool version"
  type        = string
  default     = "1.35"
}

variable "main_node_vm_size" {
  description = "VM size for the main (system) node pool"
  type        = string
  default     = "Standard_B2s_v2"
}

variable "tools_node_vm_size" {
  description = "VM size for the tools node pool"
  type        = string
  default     = "Standard_B2s_v2"
}

variable "monitoring_node_vm_size" {
  description = "VM size for the monitoring node pool"
  type        = string
  default     = "Standard_B2s_v2"
}

variable "pod_cidr" {
  description = "Non-routable CIDR for Azure CNI Overlay pod IPs"
  type        = string
  default     = "192.168.0.0/16"
}

variable "service_cidr" {
  description = "CIDR for Kubernetes service ClusterIPs"
  type        = string
  default     = "172.16.0.0/16"
}

variable "dns_service_ip" {
  description = "IP within service_cidr for the cluster DNS service"
  type        = string
  default     = "172.16.0.10"
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

variable "jumpbox_vm_size" {
  description = "VM size for the jumpbox"
  type        = string
  default     = "Standard_B2s_v2"
}

variable "jumpbox_subnet_cidr" {
  description = "CIDR for the jumpbox subnet"
  type        = string
  default     = "10.0.2.0/28"
}

variable "voyager_public_ip" {
  description = "Public IP of the voyager control box, allowed to SSH into the jumpbox"
  type        = string
  default     = "65.109.11.230"
}

variable "admin_kubeconfig_path" {
  description = "Path to the AKS admin kubeconfig, fetched via az aks get-credentials --admin. Used only to source cert material for the kubernetes/helm providers; the actual connection goes through a local SSH tunnel (see argocd.tf)."
  type        = string
  default     = "/root/.kube/aks-test-admin-config"
}

variable "aks_tunnel_local_port" {
  description = "Local port on the Terraform host that an SSH tunnel through the jumpbox forwards to the AKS private API server. Must be started manually before plan/apply (see argocd.tf comment)."
  type        = number
  default     = 16443
}

variable "gitlab_repo_token" {
  description = "GitLab Project Access Token (read_repository scope) for ArgoCD to pull server-sorcery-101"
  type        = string
  sensitive   = true
}

variable "gitlab_repo_url" {
  description = "HTTPS URL of the server-sorcery-101 GitLab repo"
  type        = string
  default     = "https://gitlab.com/kipkiruivans/server-sorcery-101.git"
}

variable "keyvault_name" {
  description = "Globally-unique name for the test Key Vault"
  type        = string
  default     = "kv-sorcery-test01"
}

variable "privatelink_subnet_cidr" {
  description = "CIDR for the Key Vault private endpoint subnet"
  type        = string
  default     = "10.0.3.0/28"
}

variable "postgres_subnet_cidr" {
  description = "CIDR for the delegated Postgres Flexible Server subnet"
  type        = string
  default     = "10.0.4.0/28"
}

variable "postgres_sku_name" {
  description = "Postgres Flexible Server SKU (tier_size)"
  type        = string
  default     = "B_Standard_B1ms"
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
  default     = 7
}

variable "postgres_admin_username" {
  description = "Postgres Flexible Server admin login"
  type        = string
  default     = "pgadmin"
}

variable "terraform_sp_object_id" {
  description = "Object ID of the terraform-sp service principal (for self-granted Key Vault data-plane roles)"
  type        = string
  default     = "3a1d86f0-3183-412b-aab0-7dfb4c198ce5"
}

variable "private_dns_zone_name" {
  description = "Placeholder private DNS zone name (real domain deferred)"
  type        = string
  default     = "test-private.example.com"
}

variable "slack_webhook_url" {
  description = "Slack incoming webhook URL for Alertmanager notifications"
  type        = string
  sensitive   = true
}
