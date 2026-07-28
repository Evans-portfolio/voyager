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
