# Local variables for Application Gateway
locals {
  backend_address_pool_name      = "appGatewayBackendPool"
  frontend_port_name_http        = "port80"
  frontend_port_name_https       = "port443"
  frontend_ip_configuration_name = "appGwPublicFrontendIp"
  http_setting_name              = "appGatewayBackendHttpSettings"
  listener_name_http             = "appGatewayHttpListener"
  listener_name_https            = "https-listener"
  request_routing_rule_name_http = "rule1"
  request_routing_rule_name_https = "https-rule"
  redirect_configuration_name    = "redirect-http-to-https"
  
  # Multi-site pools
  pool_app1_name = "pool-app1"
  pool_app2_name = "pool-app2"
  
  # Multi-site listeners
  listener_app1_name = "listener-app1"
  listener_app2_name = "listener-app2"
  
  # URL path map
  url_path_map_name = "path-map-basic"
  
  # Rewrite rule set
  rewrite_rule_set_name = "security-headers"
  
  # Health probe
  health_probe_name = "health-probe-custom"
}

# Self-signed certificate for HTTPS (for lab purposes only)
resource "azurerm_key_vault" "appgw_kv" {
  count                      = var.create_self_signed_cert ? 1 : 0
  name                       = "kv-appgw-${random_string.suffix.result}"
  location                   = azurerm_resource_group.appgw_lab.location
  resource_group_name        = azurerm_resource_group.appgw_lab.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    certificate_permissions = [
      "Create",
      "Delete",
      "Get",
      "Import",
      "List",
      "Update",
    ]

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
    ]
  }
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

data "azurerm_client_config" "current" {}

# Application Gateway
resource "azurerm_application_gateway" "appgw" {
  name                = var.appgw_name
  location            = azurerm_resource_group.appgw_lab.location
  resource_group_name = azurerm_resource_group.appgw_lab.name

  sku {
    name     = var.appgw_sku_name
    tier     = var.appgw_sku_tier
    capacity = var.appgw_capacity
  }

  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  frontend_port {
    name = local.frontend_port_name_http
    port = 80
  }

  frontend_port {
    name = local.frontend_port_name_https
    port = 443
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  # Backend Address Pools
  backend_address_pool {
    name         = local.backend_address_pool_name
    ip_addresses = [var.vm1_private_ip, var.vm2_private_ip]
  }

  backend_address_pool {
    name         = local.pool_app1_name
    ip_addresses = [var.vm1_private_ip]
  }

  backend_address_pool {
    name         = local.pool_app2_name
    ip_addresses = [var.vm2_private_ip]
  }

  # Backend HTTP Settings
  backend_http_settings {
    name                                = local.http_setting_name
    cookie_based_affinity               = "Enabled"
    affinity_cookie_name                = "AppGatewayAffinity"
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 60
    probe_name                          = local.health_probe_name
    pick_host_name_from_backend_address = false
  }

  # Custom Health Probe
  probe {
    name                                      = local.health_probe_name
    protocol                                  = "Http"
    path                                      = "/"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = false
    host                                      = "127.0.0.1"
    match {
      status_code = ["200-399"]
    }
  }

  # HTTP Listener
  http_listener {
    name                           = local.listener_name_http
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name_http
    protocol                       = "Http"
  }

  # HTTPS Listener (Default)
  http_listener {
    name                           = local.listener_name_https
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name_https
    protocol                       = "Https"
    ssl_certificate_name           = "ssl-cert-lab"
    require_sni                    = false
  }

  # Multi-site listener for app1.appgwlab.local
  http_listener {
    name                           = local.listener_app1_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name_https
    protocol                       = "Https"
    ssl_certificate_name           = "ssl-cert-lab"
    host_name                      = "app1.appgwlab.local"
    require_sni                    = true
  }

  # Multi-site listener for app2.appgwlab.local
  http_listener {
    name                           = local.listener_app2_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name_https
    protocol                       = "Https"
    ssl_certificate_name           = "ssl-cert-lab"
    host_name                      = "app2.appgwlab.local"
    require_sni                    = true
  }

  # SSL Certificate (self-signed for lab)
  ssl_certificate {
    name     = "ssl-cert-lab"
    data     = var.ssl_certificate_data
    password = var.ssl_certificate_password
  }

  # Request Routing Rule - HTTP (Basic)
  request_routing_rule {
    name                       = local.request_routing_rule_name_http
    priority                   = 100
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name_http
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }

  # Request Routing Rule - Multi-site app1 (Higher priority to match hostname first)
  request_routing_rule {
    name                       = "rule-app1"
    priority                   = 150
    rule_type                  = "Basic"
    http_listener_name         = local.listener_app1_name
    backend_address_pool_name  = local.pool_app1_name
    backend_http_settings_name = local.http_setting_name
  }

  # Request Routing Rule - Multi-site app2 (Higher priority to match hostname first)
  request_routing_rule {
    name                       = "rule-app2"
    priority                   = 160
    rule_type                  = "Basic"
    http_listener_name         = local.listener_app2_name
    backend_address_pool_name  = local.pool_app2_name
    backend_http_settings_name = local.http_setting_name
  }

  # Request Routing Rule - HTTPS (Path-based with rewrite rules - lower priority as catch-all)
  request_routing_rule {
    name                       = local.request_routing_rule_name_https
    priority                   = 200
    rule_type                  = "PathBasedRouting"
    http_listener_name         = local.listener_name_https
    url_path_map_name          = local.url_path_map_name
    rewrite_rule_set_name      = local.rewrite_rule_set_name
  }

  # URL Path Map for path-based routing
  url_path_map {
    name                               = local.url_path_map_name
    default_backend_address_pool_name  = local.pool_app2_name
    default_backend_http_settings_name = local.http_setting_name

    path_rule {
      name                       = "api-rule"
      paths                      = ["/api/*"]
      backend_address_pool_name  = local.pool_app1_name
      backend_http_settings_name = local.http_setting_name
    }

    path_rule {
      name                       = "videos-rule"
      paths                      = ["/videos/*"]
      backend_address_pool_name  = local.pool_app2_name
      backend_http_settings_name = local.http_setting_name
    }
  }

  # Rewrite Rule Set for Security Headers
  rewrite_rule_set {
    name = local.rewrite_rule_set_name

    rewrite_rule {
      name          = "add-hsts"
      rule_sequence = 100

      response_header_configuration {
        header_name  = "Strict-Transport-Security"
        header_value = "max-age=31536000; includeSubDomains"
      }
    }

    rewrite_rule {
      name          = "add-xframe"
      rule_sequence = 110

      response_header_configuration {
        header_name  = "X-Frame-Options"
        header_value = "SAMEORIGIN"
      }
    }

    rewrite_rule {
      name          = "add-xcontent"
      rule_sequence = 120

      response_header_configuration {
        header_name  = "X-Content-Type-Options"
        header_value = "nosniff"
      }
    }
  }

  # SSL Policy - Use modern TLS version
  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  # Enable WAF if using WAF_v2 tier
  dynamic "waf_configuration" {
    for_each = var.appgw_sku_tier == "WAF_v2" ? [1] : []
    content {
      enabled                  = true
      firewall_mode            = var.waf_mode
      rule_set_type            = "OWASP"
      rule_set_version         = "3.2"
      file_upload_limit_mb     = 100
      max_request_body_size_kb = 128
    }
  }

  depends_on = [
    azurerm_public_ip.appgw_pip,
    azurerm_subnet.appgw_subnet
  ]
}
