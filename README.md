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

### Prerequisites for Testing

First, get your Application Gateway public IP:
```powershell
terraform output
```

Note the `appgw_public_ip` value - you'll use this for all tests below.

---

### **Step 1: Test Basic Load Balancing (HTTP)**

Test that traffic distributes between VM1 and VM2:

```powershell
# Make 10 requests to see load balancing in action
for ($i=1; $i -le 10; $i++) { 
    Write-Host "Request $i :"
    curl http://4.240.54.83 -UseBasicParsing | Select-String "Backend Server"
}
```

**Expected Result:** Traffic alternates between "Backend Server 1" and "Backend Server 2"

**✅ Success Criteria:** 
- You see responses from both Backend Server 1 and Backend Server 2
- Distribution is roughly equal (5 requests each)

---

### **Step 2: Test SSL Termination (HTTPS)**

Verify HTTPS connections work with SSL offloading:

```powershell
# Windows PowerShell - Ignore self-signed certificate warnings
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
Invoke-WebRequest -Uri https://4.240.54.83 -UseBasicParsing | Select-Object -ExpandProperty Content
```

Alternative for Linux/WSL:
```bash
curl -k https://4.240.54.83
```

**Expected Result:** Successful HTTPS connection with HTML response from backend VMs

**✅ Success Criteria:**
- Connection succeeds over HTTPS (port 443)
- Response contains backend server information
- No connection errors

---

### **Step 3: Test Path-Based Routing**

Test that different URL paths route to different backend pools:

```powershell
# Test /api/* path → should route to VM1 (pool-app1)
Write-Host "`n--- Testing /api/* path ---"
curl -k https://4.240.54.83/api/test -UseBasicParsing | Select-String "Backend Server"

# Test /videos/* path → should route to VM2 (pool-app2)
Write-Host "`n--- Testing /videos/* path ---"
curl -k https://4.240.54.83/videos/test.mp4 -UseBasicParsing | Select-String "Backend Server"

# Test default path → should route to VM2 (default pool)
Write-Host "`n--- Testing default path ---"
curl -k https://4.240.54.83/ -UseBasicParsing | Select-String "Backend Server"
```

**Expected Results:**
- `/api/*` → Backend Server 1 (VM1 - 10.0.2.4)
- `/videos/*` → Backend Server 2 (VM2 - 10.0.2.5)
- `/` (default) → Backend Server 2 (default pool)

**✅ Success Criteria:**
- Each path routes to the correct backend
- Path-based routing rules are working
- URL path map configuration is effective

---

### **Step 4: Test Multi-Site Hosting**

Test hostname-based routing with different virtual hosts:

```powershell
# Test app1.appgwlab.local → routes to VM1 (pool-app1)
Write-Host "`n--- Testing app1.appgwlab.local ---"
curl -k -H "Host: app1.appgwlab.local" https://4.240.54.83 -UseBasicParsing | Select-String "Backend Server"

# Test app2.appgwlab.local → routes to VM2 (pool-app2)
Write-Host "`n--- Testing app2.appgwlab.local ---"
curl -k -H "Host: app2.appgwlab.local" https://4.240.54.83 -UseBasicParsing | Select-String "Backend Server"
```

**Expected Results:**
- `app1.appgwlab.local` → Backend Server 1 (VM1)
- `app2.appgwlab.local` → Backend Server 2 (VM2)

**✅ Success Criteria:**
- Host header routing works correctly
- Each hostname routes to its designated backend pool
- Multi-site listeners are configured properly

---

### **Step 5: Test Security Headers (Rewrite Rules)**

Verify that security headers are added by Application Gateway:

```powershell
# Check response headers
curl -kI https://4.240.54.83
```

**Expected Headers:**
- `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- `X-Frame-Options: SAMEORIGIN`
- `X-Content-Type-Options: nosniff`

**✅ Success Criteria:**
- All three security headers are present in the response
- Header values match the configured rewrite rules
- Headers are added to all HTTPS responses

---

### **Step 6: Test Session Affinity (Cookie-Based)**

Test that session persistence keeps requests on the same backend:

```powershell
# First request - creates a session and saves the cookie
$response1 = Invoke-WebRequest -Uri https://4.240.54.83 -UseBasicParsing -SessionVariable session
Write-Host "First request:"
$response1.Content | Select-String "Backend Server"

# Subsequent requests with the same session - should stick to the same backend
$response2 = Invoke-WebRequest -Uri https://4.240.54.83 -UseBasicParsing -WebSession $session
Write-Host "Second request (with session):"
$response2.Content | Select-String "Backend Server"

$response3 = Invoke-WebRequest -Uri https://4.240.54.83 -UseBasicParsing -WebSession $session
Write-Host "Third request (with session):"
$response3.Content | Select-String "Backend Server"
```

**Expected Result:** All requests with the session go to the **same** backend server

**✅ Success Criteria:**
- Cookie `AppGatewayAffinity` is set in the first response
- All subsequent requests with the cookie route to the same backend
- Session persistence is maintained across multiple requests

---

### **Step 7: Check Backend Health Status**

Verify that both backend VMs are healthy:

```powershell
az network application-gateway show-backend-health `
  --resource-group rg-appgw-lab `
  --name appgw-lab-basic `
  --output table
```

**Expected Result:** Both VMs showing **"Healthy"** status

**✅ Success Criteria:**
- Both backend servers report "Healthy" status
- Health probe is successfully reaching both VMs
- HTTP status codes are in the 200-399 range

---

### **Step 8: View Application Gateway Status**

Check the operational state of the Application Gateway:

```powershell
az network application-gateway show `
  --resource-group rg-appgw-lab `
  --name appgw-lab-basic `
  --query "{Name:name, OperationalState:operationalState, ProvisioningState:provisioningState}" `
  --output table
```

**Expected Result:** 
- OperationalState: **Running**
- ProvisioningState: **Succeeded**

---

### **Step 9: Query Log Analytics (Wait 5-15 minutes after deployment)**

View access logs and traffic patterns:

```powershell
# Get workspace ID
$workspaceId = terraform output -raw log_analytics_workspace_id

# Query recent access logs
az monitor log-analytics query `
  --workspace $workspaceId `
  --analytics-query "AzureDiagnostics | where ResourceType == 'APPLICATIONGATEWAYS' and Category == 'ApplicationGatewayAccessLog' | where TimeGenerated > ago(1h) | project TimeGenerated, clientIP_s, requestUri_s, httpStatus_d, serverRouted_s | take 20" `
  --output table

# Check load balancing distribution
az monitor log-analytics query `
  --workspace $workspaceId `
  --analytics-query "AzureDiagnostics | where ResourceType == 'APPLICATIONGATEWAYS' | summarize Requests=count() by serverRouted_s" `
  --output table
```

**Expected Result:** 
- Access logs show recent requests
- Traffic is distributed across both backend servers

**✅ Success Criteria:**
- Logs are being collected in Log Analytics
- You can see request details (client IP, URI, status code, backend server)
- Load balancing distribution is visible

---

### **Step 10: Performance Testing (Optional)**

Test with multiple concurrent requests:

```powershell
# Simple load test - 50 requests with 10 parallel threads
1..50 | ForEach-Object -Parallel {
    try {
        $response = Invoke-WebRequest -Uri "https://4.240.54.83" -UseBasicParsing -TimeoutSec 5
        Write-Host "Request $_ : $($response.StatusCode)"
    } catch {
        Write-Host "Request $_ : Failed - $($_.Exception.Message)"
    }
} -ThrottleLimit 10
```

**Expected Result:** All requests complete successfully with 200 status codes

**✅ Success Criteria:**
- Application Gateway handles concurrent requests
- No timeouts or failures
- Response times are acceptable

---

### **Quick Test All Features Script**

Save this as `test-appgw.ps1` for automated testing:

```powershell
# Get the public IP from Terraform output
$IP = (terraform output -raw appgw_public_ip)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

Write-Host "=== Testing Application Gateway: $IP ===" -ForegroundColor Green

Write-Host "`n1. Load Balancing Test:" -ForegroundColor Yellow
1..5 | ForEach-Object { 
    curl "http://$IP" -UseBasicParsing | Select-String "Backend Server"
}

Write-Host "`n2. HTTPS Test:" -ForegroundColor Yellow
curl -k "https://$IP" -UseBasicParsing | Select-String "Backend Server"

Write-Host "`n3. Path-Based Routing - /api/*:" -ForegroundColor Yellow
curl -k "https://$IP/api/test" -UseBasicParsing | Select-String "Backend Server"

Write-Host "`n4. Path-Based Routing - /videos/*:" -ForegroundColor Yellow
curl -k "https://$IP/videos/test.mp4" -UseBasicParsing | Select-String "Backend Server"

Write-Host "`n5. Multi-Site - app1:" -ForegroundColor Yellow
curl -k -H "Host: app1.appgwlab.local" "https://$IP" -UseBasicParsing | Select-String "Backend Server"

Write-Host "`n6. Multi-Site - app2:" -ForegroundColor Yellow
curl -k -H "Host: app2.appgwlab.local" "https://$IP" -UseBasicParsing | Select-String "Backend Server"

Write-Host "`n7. Security Headers:" -ForegroundColor Yellow
curl -kI "https://$IP" | Select-String "Strict-Transport-Security|X-Frame-Options|X-Content-Type-Options"

Write-Host "`n8. Backend Health:" -ForegroundColor Yellow
az network application-gateway show-backend-health `
  --resource-group rg-appgw-lab `
  --name appgw-lab-basic `
  --query "backendAddressPools[].backendHttpSettingsCollection[].servers[].{Address:address, Health:health}" `
  --output table

Write-Host "`n=== Testing Complete ===" -ForegroundColor Green
```

Run it:
```powershell
.\test-appgw.ps1
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
