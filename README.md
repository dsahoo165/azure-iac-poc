# Azure Application Gateway Lab - Terraform Configuration

This Terraform configuration recreates the complete Azure Application Gateway learning lab with all advanced features including load balancing, SSL termination, multi-site hosting, path-based routing, header rewrite rules, custom health probes, and Log Analytics monitoring.

## 📋 Features Implemented

### Core Features
- ✅ **Basic Load Balancing** - Round-robin traffic distribution between 2 backend VMs
- ✅ **SSL Termination** - HTTPS offloading at Application Gateway
- ✅ **Multi-Site Hosting** - Host multiple applications with different hostnames
- ✅ **Path-Based Routing** - Route traffic based on URL paths (`/api/*`, `/videos/*`)
- ✅ **Session Affinity** - Cookie-based session persistence
- ✅ **Custom Health Probes** - Monitor backend VM health
- ✅ **Header Rewrite Rules** - Add security headers (HSTS, X-Frame-Options, X-Content-Type-Options)
- ✅ **Log Analytics Integration** - Comprehensive monitoring and diagnostics
- ✅ **WAF Support** - Optional Web Application Firewall (WAF_v2 SKU)

### Infrastructure
- Virtual Network with 2 subnets (Application Gateway + Backend VMs)
- 2 Ubuntu VMs running Nginx web servers
- Network Security Group for backend protection
- Public IP for Application Gateway
- Log Analytics Workspace for monitoring

## 📂 File Structure

```
terraform/
├── main.tf                    # Provider and resource group
├── network.tf                 # VNet, subnets, NSG, public IP
├── vms.tf                     # Backend VMs (vm-web1, vm-web2)
├── app_gateway.tf             # Application Gateway with all features
├── monitoring.tf              # Log Analytics and diagnostics
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── cloud-init-web1.txt        # VM1 cloud-init script
├── cloud-init-web2.txt        # VM2 cloud-init script
├── terraform.tfvars.example   # Example variables file
└── README.md                  # This file
```

## 🚀 Prerequisites

1. **Azure CLI** installed and authenticated
   ```powershell
   az login
   az account set --subscription "your-subscription-id"
   ```

2. **Terraform** installed (version >= 1.0)
   ```powershell
   # Install via Chocolatey
   choco install terraform
   
   # Or download from: https://www.terraform.io/downloads
   ```

3. **SSH Key Pair** for VM authentication
   ```powershell
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/appgw_lab_rsa
   ```

4. **SSL Certificate** (use existing `appgw-cert.pfx` or create new)
   ```powershell
   # Convert PFX to base64
   $cert = [Convert]::ToBase64String([IO.File]::ReadAllBytes("c:\TFE\AppGateway\appgw-cert.pfx"))
   $cert | Out-File cert_base64.txt
   ```

## 📝 Configuration Steps

### Step 1: Prepare Variables File

1. Copy the example variables file:
   ```powershell
   cd c:\TFE\azure-iac-poc
   Copy-Item terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` and fill in required values:
   ```hcl
   # SSH Public Key (REQUIRED)
   ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC..."
   
   # SSL Certificate Base64 (REQUIRED)
   ssl_certificate_data = "MIIKe..."
   ssl_certificate_password = ""  # If password-protected
   
   # Optional: Change SKU to enable WAF
   appgw_sku_tier = "WAF_v2"
   waf_mode = "Detection"
   ```

### Step 2: Initialize Terraform

```powershell
terraform init
```

This will:
- Download the Azure provider
- Initialize the backend
- Prepare the working directory

### Step 3: Review the Plan

```powershell
terraform plan
```

Review the resources that will be created:
- 1 Resource Group
- 1 Virtual Network
- 2 Subnets
- 1 Network Security Group
- 1 Public IP
- 2 Network Interfaces
- 2 Linux VMs
- 1 Application Gateway (with 4 listeners, 3 backend pools, 4 routing rules)
- 1 Log Analytics Workspace (if enabled)
- 1 Diagnostic Setting

### Step 4: Deploy Infrastructure

```powershell
terraform apply
```

Type `yes` when prompted. Deployment takes approximately **10-15 minutes**.

### Step 5: Get Outputs

```powershell
terraform output
```

Example output:
```
appgw_public_ip = "74.225.226.223"
vm1_private_ip = "10.0.2.4"
vm2_private_ip = "10.0.2.5"
test_http_command = "curl http://74.225.226.223"
test_https_command = "curl -k https://74.225.226.223"
```

## 🧪 Testing the Deployment

### 1. Test Basic Load Balancing (HTTP)

```bash
# Make multiple requests to see load balancing
for ($i=1; $i -le 10; $i++) { 
    curl http://<APPGW_PUBLIC_IP> -UseBasicParsing | Select-String "Backend Server"
}
```

**Expected:** Traffic alternates between "Backend Server 1" and "Backend Server 2"

### 2. Test SSL Termination (HTTPS)

```bash
# Windows PowerShell
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
curl https://<APPGW_PUBLIC_IP> -UseBasicParsing

# Linux/WSL
curl -k https://<APPGW_PUBLIC_IP>
```

### 3. Test Path-Based Routing

```bash
# Requests to /api/* should route to VM1 (10.0.2.4)
curl -k https://<APPGW_PUBLIC_IP>/api/test

# Requests to /videos/* should route to VM2 (10.0.2.5)
curl -k https://<APPGW_PUBLIC_IP>/videos/test.mp4

# Other paths should route to VM2 (default pool)
curl -k https://<APPGW_PUBLIC_IP>/
```

### 4. Test Multi-Site Hosting

```bash
# Route to VM1 using app1 hostname
curl -k -H "Host: app1.appgwlab.local" https://<APPGW_PUBLIC_IP>

# Route to VM2 using app2 hostname
curl -k -H "Host: app2.appgwlab.local" https://<APPGW_PUBLIC_IP>
```

### 5. Test Security Headers

```bash
# Check response headers
curl -kI https://<APPGW_PUBLIC_IP>
```

**Expected headers:**
- `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- `X-Frame-Options: SAMEORIGIN`
- `X-Content-Type-Options: nosniff`

### 6. Test Session Affinity

```bash
# Save cookies
curl -k -c cookies.txt https://<APPGW_PUBLIC_IP>/

# Make requests with cookie (should stick to same backend)
curl -k -b cookies.txt https://<APPGW_PUBLIC_IP>/
curl -k -b cookies.txt https://<APPGW_PUBLIC_IP>/
```

### 7. Check Backend Health

```powershell
az network application-gateway show-backend-health `
  --resource-group rg-appgw-lab `
  --name appgw-lab-basic `
  --output table
```

**Expected:** Both VMs showing "Healthy"

### 8. Query Log Analytics

Wait 5-15 minutes after deployment, then query logs:

```powershell
# Get workspace ID
$workspaceId = terraform output -raw log_analytics_workspace_id

# Query recent requests
az monitor log-analytics query `
  --workspace $workspaceId `
  --analytics-query "AzureDiagnostics | where ResourceType == 'APPLICATIONGATEWAYS' and Category == 'ApplicationGatewayAccessLog' | where TimeGenerated > ago(1h) | take 20" `
  --output table
```

## 🔧 Customization Options

### Enable Web Application Firewall (WAF)

Edit `terraform.tfvars`:
```hcl
appgw_sku_tier = "WAF_v2"
waf_mode       = "Detection"  # or "Prevention"
```

Then apply:
```powershell
terraform apply
```

### Increase Capacity (Scaling)

Edit `terraform.tfvars`:
```hcl
appgw_capacity = 2  # Increase from 1 to 2 instances
```

### Change VM Size

Edit `terraform.tfvars`:
```hcl
vm_size = "Standard_B2ms"  # Upgrade from B2s
```

### Disable Monitoring (Cost Savings)

Edit `terraform.tfvars`:
```hcl
enable_diagnostics = false
```

## 💰 Cost Estimation

**Standard_v2 SKU (1 instance):**
- Application Gateway: ~$175/month
- VMs (2x B2s): ~$60/month
- Storage: ~$5/month
- Log Analytics: ~$10/month (with basic usage)
- **Total: ~$250/month**

**WAF_v2 SKU (1 instance):**
- Application Gateway: ~$265/month
- VMs + Storage + Logs: ~$75/month
- **Total: ~$340/month**

**Cost Optimization Tips:**
- Use `appgw_capacity = 1` for lab/dev environments
- Set `enable_diagnostics = false` if not needed
- Stop/deallocate VMs when not in use: `az vm deallocate --ids $(az vm list -g rg-appgw-lab --query "[].id" -o tsv)`

## 🧹 Cleanup

### Destroy All Resources

```powershell
terraform destroy
```

Type `yes` when prompted. This will delete:
- All VMs and disks
- Application Gateway
- Networking resources
- Log Analytics workspace
- Resource group

**⚠️ Warning:** This action is irreversible!

### Partial Cleanup (Keep Networking)

If you want to keep the VNet and just remove expensive resources:

```powershell
# Remove Application Gateway only
terraform destroy -target=azurerm_application_gateway.appgw

# Remove VMs only
terraform destroy -target=azurerm_linux_virtual_machine.vm_web1 -target=azurerm_linux_virtual_machine.vm_web2
```

## 📊 Monitoring & Troubleshooting

### View Application Gateway Logs

```powershell
# Recent access logs
az monitor log-analytics query `
  --workspace <WORKSPACE_ID> `
  --analytics-query "AzureDiagnostics | where ResourceType == 'APPLICATIONGATEWAYS' and Category == 'ApplicationGatewayAccessLog' | where TimeGenerated > ago(1h) | project TimeGenerated, clientIP_s, requestUri_s, httpStatus_d, serverRouted_s" `
  --output table

# Load balancing distribution
az monitor log-analytics query `
  --workspace <WORKSPACE_ID> `
  --analytics-query "AzureDiagnostics | where ResourceType == 'APPLICATIONGATEWAYS' | summarize Requests=count() by serverRouted_s" `
  --output table
```

### Common Issues

**Issue:** Backend showing unhealthy
```powershell
# Check NSG rules
az network nsg show --resource-group rg-appgw-lab --name nsg-backend-vms

# Check VM status
az vm list --resource-group rg-appgw-lab --query "[].{Name:name, PowerState:powerState}" --output table

# SSH to VM and check nginx
az vm run-command invoke --resource-group rg-appgw-lab --name vm-web1 --command-id RunShellScript --scripts "sudo systemctl status nginx"
```

**Issue:** SSL certificate errors
- Verify certificate is valid and properly base64-encoded
- Check certificate password if PFX is protected
- Ensure certificate matches hostname (for production)

**Issue:** Path-based routing not working
- Verify URL path map configuration
- Check that routing rule is set to "PathBasedRouting" type
- Test with explicit paths: `/api/test`, `/videos/sample.mp4`

## 🔐 Security Best Practices

### For Production Use:

1. **Use proper SSL certificates** from a trusted CA (not self-signed)
2. **Enable WAF** with Prevention mode
3. **Restrict NSG rules** to only required traffic
4. **Use Azure Key Vault** for certificate management
5. **Enable Azure DDoS Protection** on the VNet
6. **Implement Azure Policy** for governance
7. **Use Managed Identities** instead of service principals
8. **Enable backup** for VMs
9. **Set up alerts** for unhealthy backends and high response times
10. **Use Private Link** for backend connectivity (advanced scenario)

## 📚 Additional Resources

- [Azure Application Gateway Documentation](https://learn.microsoft.com/en-us/azure/application-gateway/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Application Gateway Components](https://learn.microsoft.com/en-us/azure/application-gateway/application-gateway-components)
- [WAF Configuration](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/ag-overview)

## 🤝 Contributing

This is a learning lab project. Feel free to:
- Add more features (autoscaling, private endpoints, etc.)
- Improve documentation
- Create additional test scenarios
- Share your learnings

## 📄 License

This project is for educational purposes. Use at your own risk.

---

**Happy Learning! 🚀**

For questions or issues, refer to the original `Application-Gateway-Learning-Lab.md` document.
