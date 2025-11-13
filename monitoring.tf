# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "appgw_law" {
  count               = var.enable_diagnostics ? 1 : 0
  name                = var.log_analytics_workspace_name
  location            = azurerm_resource_group.appgw_lab.location
  resource_group_name = azurerm_resource_group.appgw_lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Diagnostic Settings for Application Gateway
resource "azurerm_monitor_diagnostic_setting" "appgw_diagnostics" {
  count                      = var.enable_diagnostics ? 1 : 0
  name                       = "appgw-diagnostics"
  target_resource_id         = azurerm_application_gateway.appgw.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.appgw_law[0].id

  # Access Logs
  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  # Performance Logs
  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  # Firewall Logs
  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  # Metrics
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
