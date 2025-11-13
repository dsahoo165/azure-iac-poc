# Virtual Network
resource "azurerm_virtual_network" "appgw_vnet" {
  name                = var.vnet_name
  location            = azurerm_resource_group.appgw_lab.location
  resource_group_name = azurerm_resource_group.appgw_lab.name
  address_space       = [var.vnet_address_space]
}

# Application Gateway Subnet
resource "azurerm_subnet" "appgw_subnet" {
  name                 = var.appgw_subnet_name
  resource_group_name  = azurerm_resource_group.appgw_lab.name
  virtual_network_name = azurerm_virtual_network.appgw_vnet.name
  address_prefixes     = [var.appgw_subnet_prefix]
}

# Backend VMs Subnet
resource "azurerm_subnet" "backend_subnet" {
  name                 = var.backend_subnet_name
  resource_group_name  = azurerm_resource_group.appgw_lab.name
  virtual_network_name = azurerm_virtual_network.appgw_vnet.name
  address_prefixes     = [var.backend_subnet_prefix]
}

# Public IP for Application Gateway
resource "azurerm_public_ip" "appgw_pip" {
  name                = var.appgw_pip_name
  location            = azurerm_resource_group.appgw_lab.location
  resource_group_name = azurerm_resource_group.appgw_lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Security Group for Backend VMs
resource "azurerm_network_security_group" "backend_nsg" {
  name                = "nsg-backend-vms"
  location            = azurerm_resource_group.appgw_lab.location
  resource_group_name = azurerm_resource_group.appgw_lab.name

  security_rule {
    name                       = "Allow-HTTP-From-AppGW"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.appgw_subnet_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTPS-From-AppGW"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.appgw_subnet_prefix
    destination_address_prefix = "*"
  }
}

# Associate NSG with Backend Subnet
resource "azurerm_subnet_network_security_group_association" "backend_nsg_assoc" {
  subnet_id                 = azurerm_subnet.backend_subnet.id
  network_security_group_id = azurerm_network_security_group.backend_nsg.id
}
