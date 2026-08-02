resource "azurerm_subnet" "jumpbox" {
  name                 = "snet-test-jumpbox"
  resource_group_name  = azurerm_resource_group.test.name
  virtual_network_name = azurerm_virtual_network.test.name
  address_prefixes     = [var.jumpbox_subnet_cidr]
}

resource "azurerm_network_security_group" "jumpbox" {
  name                = "nsg-test-jumpbox"
  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location

  security_rule {
    name                       = "AllowSSHFromVoyager"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${var.voyager_public_ip}/32"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInBound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # test-ip-flow-verify showed outbound traffic to prod's peered range hitting
  # the default DenyAllOutBound rule, not the default AllowVnetOutBound rule -
  # the "VirtualNetwork" service tag isn't reliably covering the peered range
  # for this NSG's outbound evaluation, even though routing (a separate
  # mechanism) correctly resolves it via VNetPeering. Explicit CIDR instead
  # of relying on the tag, same reasoning already applied to prod's inbound
  # NSGs.
  security_rule {
    name                       = "AllowOutboundToProd"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = var.prod_vnet_address_space
  }
}

resource "azurerm_subnet_network_security_group_association" "jumpbox" {
  subnet_id                 = azurerm_subnet.jumpbox.id
  network_security_group_id = azurerm_network_security_group.jumpbox.id
}

resource "azurerm_public_ip" "jumpbox" {
  name                = "pip-test-jumpbox"
  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "jumpbox" {
  name                = "nic-test-jumpbox"
  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.jumpbox.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpbox.id
  }
}

resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                  = "vm-test-jumpbox"
  resource_group_name   = azurerm_resource_group.test.name
  location              = azurerm_resource_group.test.location
  size                  = var.jumpbox_vm_size
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.jumpbox.id]

  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = trimspace(file("${path.module}/jumpbox_ssh_key.pub"))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(file("${path.module}/jumpbox-cloud-init.yaml"))
}

resource "azurerm_role_assignment" "jumpbox_aks_user" {
  scope                = azurerm_kubernetes_cluster.test.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azurerm_linux_virtual_machine.jumpbox.identity[0].principal_id
}
