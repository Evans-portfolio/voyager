resource "azurerm_kubernetes_cluster" "prod" {
  name                = "aks-prod"
  resource_group_name = azurerm_resource_group.prod.name
  location            = azurerm_resource_group.prod.location
  dns_prefix          = "aks-prod-sorcery"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Standard" # HA control plane - the only real HA this design achieves at 1 node; see main pool comment below

  private_cluster_enabled             = true
  private_cluster_public_fqdn_enabled = false
  oidc_issuer_enabled                 = true
  workload_identity_enabled           = true

  default_node_pool {
    name           = "main"
    vm_size        = var.main_node_vm_size
    node_count     = 1
    zones          = ["1", "2", "3"]
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

# zones=["1","2","3"] on the main pool is structural readiness only, not real
# redundancy - at node_count=1 there's a single node in one zone at a time.
# Real multi-node zone spread needs more quota than this subscription has
# right now. The control plane (sku_tier=Standard above) is genuinely
# multi-zone HA, managed by Azure regardless of node count.

resource "azurerm_kubernetes_cluster_node_pool" "tools" {
  name                  = "tools"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.prod.id
  vm_size               = var.tools_node_vm_size
  node_count            = 0 # start at 0, same quota-conservation pattern as test's monitoring pool - scale up once headroom allows
  vnet_subnet_id        = azurerm_subnet.aks.id
  mode                  = "User"

  priority        = "Spot"
  eviction_policy = "Delete"
  spot_max_price  = -1

  node_taints = ["kubernetes.azure.com/scalesetpriority=spot:NoSchedule"]
}

resource "azurerm_kubernetes_cluster_node_pool" "monitoring" {
  name                  = "monitoring"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.prod.id
  vm_size               = var.monitoring_node_vm_size
  node_count            = 0
  vnet_subnet_id        = azurerm_subnet.aks.id
  mode                  = "User"

  upgrade_settings {
    max_surge = "10%"
  }
}
