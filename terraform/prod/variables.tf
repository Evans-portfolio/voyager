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
