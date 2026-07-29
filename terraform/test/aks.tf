resource "azurerm_kubernetes_cluster" "test" {
  name                = "aks-test"
  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location
  dns_prefix          = "aks-test-sorcery"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"

  private_cluster_enabled             = true
  private_cluster_public_fqdn_enabled = false
  oidc_issuer_enabled                 = true
  workload_identity_enabled           = true

  default_node_pool {
    name           = "main"
    vm_size        = var.main_node_vm_size
    node_count     = 1
    vnet_subnet_id = azurerm_subnet.aks.id

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    outbound_type       = "userAssignedNATGateway"
  }

  depends_on = [
    azurerm_subnet_nat_gateway_association.aks,
  ]
}

resource "azurerm_kubernetes_cluster_node_pool" "tools" {
  name                  = "tools"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.test.id
  vm_size               = var.tools_node_vm_size
  node_count            = 1
  vnet_subnet_id        = azurerm_subnet.aks.id
  mode                  = "User"

  priority        = "Spot"
  eviction_policy = "Delete"
  spot_max_price  = -1

  node_taints = ["kubernetes.azure.com/scalesetpriority=spot:NoSchedule"]
}

resource "azurerm_kubernetes_cluster_node_pool" "monitoring" {
  name                  = "monitoring"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.test.id
  vm_size               = var.monitoring_node_vm_size
  node_count            = 0 # scaled to 0: no workload scheduled here yet, frees vCPU quota for jumpbox.tf
  vnet_subnet_id        = azurerm_subnet.aks.id
  mode                  = "User"

  upgrade_settings {
    max_surge = "10%"
  }
}
