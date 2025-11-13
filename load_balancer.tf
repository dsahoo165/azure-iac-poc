# ========================================
# Azure Load Balancer Configuration
# ========================================
# This demonstrates Azure Load Balancer - Layer 4 (TCP/UDP) load balancing
# Key differences from Application Gateway:
# - Works at Transport Layer (Layer 4) vs Application Layer (Layer 7)
# - No SSL termination, URL routing, or WAF capabilities
# - Lower cost and simpler configuration
# - Better for non-HTTP workloads

# Load Balancer Subnet
resource "azurerm_subnet" "lb_subnet" {
  name                 = var.lb_subnet_name
  resource_group_name  = azurerm_resource_group.appgw_lab.name
  virtual_network_name = azurerm_virtual_network.appgw_vnet.name
  address_prefixes     = [var.lb_subnet_prefix]
}

# Public IP for Load Balancer (Standard SKU)
resource "azurerm_public_ip" "lb_pip" {
  name                = var.lb_pip_name
  location            = azurerm_resource_group.appgw_lab.location
  resource_group_name = azurerm_resource_group.appgw_lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = {
    Environment = "Lab"
    Purpose     = "Load Balancer"
  }
}

# Azure Load Balancer (Standard SKU)
resource "azurerm_lb" "web_lb" {
  name                = var.lb_name
  location            = azurerm_resource_group.appgw_lab.location
  resource_group_name = azurerm_resource_group.appgw_lab.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "lb-frontend-ip"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }

  tags = {
    Environment = "Lab"
    Purpose     = "Web Load Balancer"
  }
}

# Backend Address Pool
resource "azurerm_lb_backend_address_pool" "web_backend_pool" {
  name            = "lb-backend-pool"
  loadbalancer_id = azurerm_lb.web_lb.id
}

# Health Probe for HTTP
resource "azurerm_lb_probe" "http_probe" {
  name                = "lb-http-probe"
  loadbalancer_id     = azurerm_lb.web_lb.id
  protocol            = "Http"
  port                = 80
  request_path        = "/"
  interval_in_seconds = 5
  number_of_probes    = 2
}

# Health Probe for TCP (alternative)
resource "azurerm_lb_probe" "tcp_probe" {
  name                = "lb-tcp-probe"
  loadbalancer_id     = azurerm_lb.web_lb.id
  protocol            = "Tcp"
  port                = 443
  interval_in_seconds = 5
  number_of_probes    = 2
}

# Load Balancing Rule for HTTP
resource "azurerm_lb_rule" "http_rule" {
  name                           = "lb-http-rule"
  loadbalancer_id                = azurerm_lb.web_lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "lb-frontend-ip"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web_backend_pool.id]
  probe_id                       = azurerm_lb_probe.http_probe.id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 4
  load_distribution              = "Default" # Options: Default, SourceIP, SourceIPProtocol
  disable_outbound_snat          = true      # Required when using outbound rules
}

# Load Balancing Rule for HTTPS
resource "azurerm_lb_rule" "https_rule" {
  name                           = "lb-https-rule"
  loadbalancer_id                = azurerm_lb.web_lb.id
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "lb-frontend-ip"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web_backend_pool.id]
  probe_id                       = azurerm_lb_probe.tcp_probe.id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 4
  load_distribution              = "Default"
  disable_outbound_snat          = true      # Required when using outbound rules
}

# Outbound Rule for SNAT
resource "azurerm_lb_outbound_rule" "outbound_rule" {
  name                    = "lb-outbound-rule"
  loadbalancer_id         = azurerm_lb.web_lb.id
  protocol                = "All"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web_backend_pool.id

  frontend_ip_configuration {
    name = "lb-frontend-ip"
  }
}

# NAT Rule for direct SSH access to VM1 (optional)
resource "azurerm_lb_nat_rule" "ssh_vm1" {
  name                           = "ssh-nat-vm1"
  resource_group_name            = azurerm_resource_group.appgw_lab.name
  loadbalancer_id                = azurerm_lb.web_lb.id
  protocol                       = "Tcp"
  frontend_port                  = 2201
  backend_port                   = 22
  frontend_ip_configuration_name = "lb-frontend-ip"
}

# NAT Rule for direct SSH access to VM2 (optional)
resource "azurerm_lb_nat_rule" "ssh_vm2" {
  name                           = "ssh-nat-vm2"
  resource_group_name            = azurerm_resource_group.appgw_lab.name
  loadbalancer_id                = azurerm_lb.web_lb.id
  protocol                       = "Tcp"
  frontend_port                  = 2202
  backend_port                   = 22
  frontend_ip_configuration_name = "lb-frontend-ip"
}

# Associate VM1 NIC with Backend Pool
resource "azurerm_network_interface_backend_address_pool_association" "vm1_lb_assoc" {
  network_interface_id    = azurerm_network_interface.vm1_nic.id
  ip_configuration_name   = "ipconfigvm-web1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web_backend_pool.id
}

# Associate VM2 NIC with Backend Pool
resource "azurerm_network_interface_backend_address_pool_association" "vm2_lb_assoc" {
  network_interface_id    = azurerm_network_interface.vm2_nic.id
  ip_configuration_name   = "ipconfigvm-web2"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web_backend_pool.id
}

# Associate NAT Rule with VM1 NIC
resource "azurerm_network_interface_nat_rule_association" "vm1_nat_assoc" {
  network_interface_id  = azurerm_network_interface.vm1_nic.id
  ip_configuration_name = "ipconfigvm-web1"
  nat_rule_id           = azurerm_lb_nat_rule.ssh_vm1.id
}

# Associate NAT Rule with VM2 NIC
resource "azurerm_network_interface_nat_rule_association" "vm2_nat_assoc" {
  network_interface_id  = azurerm_network_interface.vm2_nic.id
  ip_configuration_name = "ipconfigvm-web2"
  nat_rule_id           = azurerm_lb_nat_rule.ssh_vm2.id
}
