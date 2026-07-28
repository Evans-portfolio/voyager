variable "location" {
  description = "Azure region for the test environment"
  type        = string
  default     = "northeurope"
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
