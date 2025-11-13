output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.appgw_lab.name
}

output "appgw_public_ip" {
  description = "Public IP address of the Application Gateway"
  value       = azurerm_public_ip.appgw_pip.ip_address
}

output "appgw_fqdn" {
  description = "FQDN of the Application Gateway (if configured)"
  value       = azurerm_public_ip.appgw_pip.fqdn
}

output "vm1_private_ip" {
  description = "Private IP address of VM1"
  value       = azurerm_network_interface.vm1_nic.private_ip_address
}

output "vm2_private_ip" {
  description = "Private IP address of VM2"
  value       = azurerm_network_interface.vm2_nic.private_ip_address
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = var.enable_diagnostics ? azurerm_log_analytics_workspace.appgw_law[0].workspace_id : null
}

output "test_http_command" {
  description = "Command to test HTTP endpoint"
  value       = "curl http://${azurerm_public_ip.appgw_pip.ip_address}"
}

output "test_https_command" {
  description = "Command to test HTTPS endpoint (skip cert verification)"
  value       = "curl -k https://${azurerm_public_ip.appgw_pip.ip_address}"
}

output "test_path_routing_api" {
  description = "Command to test /api/* path routing"
  value       = "curl -k https://${azurerm_public_ip.appgw_pip.ip_address}/api/test"
}

output "test_path_routing_videos" {
  description = "Command to test /videos/* path routing"
  value       = "curl -k https://${azurerm_public_ip.appgw_pip.ip_address}/videos/test.mp4"
}

output "test_multisite_app1" {
  description = "Command to test multi-site routing for app1"
  value       = "curl -k -H 'Host: app1.appgwlab.local' https://${azurerm_public_ip.appgw_pip.ip_address}"
}

output "test_multisite_app2" {
  description = "Command to test multi-site routing for app2"
  value       = "curl -k -H 'Host: app2.appgwlab.local' https://${azurerm_public_ip.appgw_pip.ip_address}"
}

output "test_security_headers" {
  description = "Command to check security headers"
  value       = "curl -kI https://${azurerm_public_ip.appgw_pip.ip_address}"
}

output "backend_health_check_command" {
  description = "Azure CLI command to check backend health"
  value       = "az network application-gateway show-backend-health --resource-group ${azurerm_resource_group.appgw_lab.name} --name ${azurerm_application_gateway.appgw.name} --output table"
}
