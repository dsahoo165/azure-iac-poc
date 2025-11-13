# Network Interface for VM1
resource "azurerm_network_interface" "vm1_nic" {
  name                = "nic-vm-web1"
  location            = azurerm_resource_group.appgw_lab.location
  resource_group_name = azurerm_resource_group.appgw_lab.name

  ip_configuration {
    name                          = "ipconfigvm-web1"
    subnet_id                     = azurerm_subnet.backend_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.vm1_private_ip
  }
}

# Network Interface for VM2
resource "azurerm_network_interface" "vm2_nic" {
  name                = "nic-vm-web2"
  location            = azurerm_resource_group.appgw_lab.location
  resource_group_name = azurerm_resource_group.appgw_lab.name

  ip_configuration {
    name                          = "ipconfigvm-web2"
    subnet_id                     = azurerm_subnet.backend_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.vm2_private_ip
  }
}

# VM1 - Web Server 1
resource "azurerm_linux_virtual_machine" "vm_web1" {
  name                  = "vm-web1"
  location              = azurerm_resource_group.appgw_lab.location
  resource_group_name   = azurerm_resource_group.appgw_lab.name
  network_interface_ids = [azurerm_network_interface.vm1_nic.id]
  size                  = var.vm_size

  os_disk {
    name                 = "osdisk-vm-web1"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name                   = "vm-web1"
  admin_username                  = var.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-web1.txt", {
    hostname   = "vm-web1"
    private_ip = var.vm1_private_ip
  }))
}

# VM2 - Web Server 2
resource "azurerm_linux_virtual_machine" "vm_web2" {
  name                  = "vm-web2"
  location              = azurerm_resource_group.appgw_lab.location
  resource_group_name   = azurerm_resource_group.appgw_lab.name
  network_interface_ids = [azurerm_network_interface.vm2_nic.id]
  size                  = var.vm_size

  os_disk {
    name                 = "osdisk-vm-web2"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name                   = "vm-web2"
  admin_username                  = var.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-web2.txt", {
    hostname   = "vm-web2"
    private_ip = var.vm2_private_ip
  }))
}
