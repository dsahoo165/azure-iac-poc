
SKU stands for Stock Keeping Unit in Azure. It represents a specific tier or configuration variant of an Azure service.
For Azure resources, the SKU determines:
Performance characteristics (CPU, memory, throughput)
Features available (basic vs. premium capabilities)
Pricing tier (cost per hour/month)
Capacity limits (max connections, requests per second)
In your Application Gateway, the SKU is Standard_v2, which means:
Tier: Standard (not WAF-enabled)
Version: v2 (autoscaling capable, zone-redundant, better performance than v1)
Capacity: Currently 2 instances
Other common Azure SKU examples:
Virtual Machines: Standard_B1s, Standard_DS1_v2 (size/performance tiers)
Storage Accounts: Standard_LRS, Premium_ZRS (redundancy/performance)
App Service Plans: B1, P1v2, S1 (basic, premium, standard)
# Application Gateway - Learning Lab Setup Guide
A comprehensive step-by-step guide to practice Azure Application Gateway, from basic to advanced scenarios.
---
## Table of Contents
- [Phase 1: Basic Setup (Foundation)](#phase-1-basic-setup-foundation)
- [Phase 2: SSL/TLS & HTTPS (Intermediate)](#phase-2-ssltls--https-intermediate)
- [Phase 3: Multi-Site Hosting (Advanced)](#phase-3-multi-site-hosting-advanced)
- [Phase 4: Web Application Firewall (WAF)](#phase-4-web-application-firewall-waf)
- [Phase 5: Advanced Routing & Rewrite Rules](#phase-5-advanced-routing--rewrite-rules)
- [Phase 6: Monitoring & Troubleshooting](#phase-6-monitoring--troubleshooting)
- [Phase 7: Health Probes & Session Affinity](#phase-7-health-probes--session-affinity)
- [Comprehensive Testing Checklist](#comprehensive-testing-checklist)
- [Learning Resources](#learning-resources)
- [Pro Tips](#pro-tips)
- [Cleanup](#cleanup)
---
## Phase 1: Basic Setup (Foundation)
### Step 1: Create Basic Infrastructure
#### 1.1 Create Resource Group
```powershell
az group create --name rg-appgw-lab --location centralindia
```
**Expected Output:** JSON confirming resource group creation
---
#### 1.2 Create Virtual Network & Subnets
```powershell
# Create VNet with App Gateway subnet
az network vnet create `
  --resource-group rg-appgw-lab `
  --name vnet-appgw-lab `
  --address-prefix 10.0.0.0/16 `
  --subnet-name subnet-appgw `
  --subnet-prefix 10.0.1.0/24
# Create backend subnet
az network vnet subnet create `
  --resource-group rg-appgw-lab `
  --vnet-name vnet-appgw-lab `
  --name subnet-backend `
  --address-prefix 10.0.2.0/24
```
**Expected Output:** VNet and subnet details
---
#### 1.3 Create Public IP
```powershell
az network public-ip create `
  --resource-group rg-appgw-lab `
  --name pip-appgw-lab `
  --sku Standard `
  --allocation-method Static
```
**Expected Output:** Public IP address (note this down for testing)
---
### Step 2: Create Backend VMs (2 simple web servers)
#### 2.1 Create cloud-init files
**Create file: `cloud-init-web1.txt`**
```yaml
#cloud-config
package_upgrade: true
packages:
  - nginx
runcmd:
  - echo "<h1>Backend Server 1</h1><p>Hostname: $(hostname)</p>" > /var/www/html/index.html
  - systemctl restart nginx
```
**Create file: `cloud-init-web2.txt`**
```yaml
#cloud-config
package_upgrade: true
packages:
  - nginx
runcmd:
  - echo "<h1>Backend Server 2</h1><p>Hostname: $(hostname)</p>" > /var/www/html/index.html
  - systemctl restart nginx
```
---
#### 2.2 Create VMs
```powershell
# VM 1 (without public IP - recommended for production)
az vm create `
  --resource-group rg-appgw-lab `
  --name vm-web1 `
  --image Ubuntu2204 `
  --vnet-name vnet-appgw-lab `
  --subnet subnet-backend `
  --admin-username azureuser `
  --generate-ssh-keys `
  --custom-data cloud-init-web1.txt `
  --size Standard_B1s `
  --public-ip-address ""
# VM 2 (without public IP - recommended for production)
az vm create `
  --resource-group rg-appgw-lab `
  --name vm-web2 `
  --image Ubuntu2204 `
  --vnet-name vnet-appgw-lab `
  --subnet subnet-backend `
  --admin-username azureuser `
  --generate-ssh-keys `
  --custom-data cloud-init-web2.txt `
  --size Standard_B1s `
  --public-ip-address ""
```
**Security Best Practice:** The `--public-ip-address ""` parameter prevents public IP assignment. Backend VMs should only be accessible through the Application Gateway, not directly from the internet.
**For Learning/Troubleshooting:** If you want to access VMs directly for troubleshooting, you can:
1. Omit the `--public-ip-address ""` parameter (VMs will get public IPs)
2. Use Azure Bastion for secure access without public IPs
3. Use `az vm run-command` to execute commands remotely
**Expected Output:** VM details with private IP addresses (note these down)
**Important:** 
- Without `--public-ip-address ""`, VMs will automatically get public IPs
- For this lab, if VMs were created with public IPs, they can be removed later (see troubleshooting section)
- In production environments, backend VMs should NEVER have public IPs
**Note:** If cloud-init doesn't execute properly, manually configure the VMs:
```powershell
# Configure VM1
az vm run-command invoke --resource-group rg-appgw-lab --name vm-web1 --command-id RunShellScript --scripts "echo '<h1>Backend Server 1</h1><p>Hostname: vm-web1</p><p>Private IP: 10.0.2.4</p>' | sudo tee /var/www/html/index.html"
# Configure VM2
az vm run-command invoke --resource-group rg-appgw-lab --name vm-web2 --command-id RunShellScript --scripts "echo '<h1>Backend Server 2</h1><p>Hostname: vm-web2</p><p>Private IP: 10.0.2.5</p>' | sudo tee /var/www/html/index.html"
```
---
#### 2.3 Open HTTP port on VMs
```powershell
az vm open-port --resource-group rg-appgw-lab --name vm-web1 --port 80
az vm open-port --resource-group rg-appgw-lab --name vm-web2 --port 80
```
---
### Step 3: Create Basic Application Gateway
#### 3.1 Get VM Private IPs
```powershell
$vm1ip = az vm show -d -g rg-appgw-lab -n vm-web1 --query privateIps -o tsv
$vm2ip = az vm show -d -g rg-appgw-lab -n vm-web2 --query privateIps -o tsv
Write-Host "VM1 IP: $vm1ip"
Write-Host "VM2 IP: $vm2ip"
```
---
#### 3.2 Create Application Gateway
```powershell
az network application-gateway create `
  --name appgw-lab-basic `
  --resource-group rg-appgw-lab `
  --vnet-name vnet-appgw-lab `
  --subnet subnet-appgw `
  --public-ip-address pip-appgw-lab `
  --capacity 2 `
  --sku Standard_v2 `
  --http-settings-cookie-based-affinity Disabled `
  --frontend-port 80 `
  --http-settings-port 80 `
  --http-settings-protocol Http `
  --priority 100 `
  --servers $vm1ip $vm2ip
```
**Expected Output:** Application Gateway creation confirmation (takes 5-10 minutes)
**Important Notes:**
- `--priority 100` parameter is required for routing rules in API version 2021-08-01 and later
- `--http-settings-cookie-based-affinity Disabled` enables true round-robin load balancing
  - **Disabled:** Each request can go to any backend (better for testing load balancing)
  - **Enabled:** Session persistence - same client always goes to same backend (use for stateful apps)
**To toggle cookie-based affinity after creation:**
```powershell
# Disable for round-robin load balancing (recommended for testing)
az network application-gateway http-settings update `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --name appGatewayBackendHttpSettings `
  --cookie-based-affinity Disabled
# Enable for session persistence (for stateful applications)
az network application-gateway http-settings update `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --name appGatewayBackendHttpSettings `
  --cookie-based-affinity Enabled
```
---
### 📊 Phase 1 Summary - What We've Created
After completing Phase 1, you should have:
| Resource | Name | Details |
|----------|------|---------|
| Resource Group | `rg-appgw-lab` | Location: Central India |
| Virtual Network | `vnet-appgw-lab` | Address Space: 10.0.0.0/16 |
| App Gateway Subnet | `subnet-appgw` | 10.0.1.0/24 |
| Backend Subnet | `subnet-backend` | 10.0.2.0/24 |
| Public IP | `pip-appgw-lab` | Static IP (e.g., 74.225.226.223) |
| VM 1 | `vm-web1` | Private IP: 10.0.2.4, Size: Standard_B1s |
| VM 2 | `vm-web2` | Private IP: 10.0.2.5, Size: Standard_B1s |
| Application Gateway | `appgw-lab-basic` | SKU: Standard_v2, Capacity: 2 instances |
| Backend Pool | `appGatewayBackendPool` | Members: 10.0.2.4, 10.0.2.5 |
| HTTP Settings | `appGatewayBackendHttpSettings` | Port 80, Cookie-based affinity disabled |
| Listener | `appGatewayHttpListener` | Protocol: HTTP, Port: 80 |
| Routing Rule | `rule1` | Priority: 100, Type: Basic |
---
### ✅ Test Scenario 1: Basic Load Balancing
#### Test Steps:
1. Get the public IP:
   ```powershell
   az network public-ip show --resource-group rg-appgw-lab --name pip-appgw-lab --query ipAddress -o tsv
   ```
2. Access in browser: `http://<PUBLIC-IP>` (e.g., `http://74.225.226.223`)
3. Refresh multiple times (Ctrl+F5) or use curl in a loop:
   ```powershell
   # Test load balancing with curl (no cookie persistence)
   for ($i=1; $i -le 10; $i++) {
       Write-Host "Request $i:"
       curl http://74.225.226.223 -UseBasicParsing | Select-String -Pattern "Backend Server|Private IP"
   }
   ```
**Expected Results:**
- You should see "Backend Server 1" and "Backend Server 2" alternating
- Different hostnames and private IPs displayed (10.0.2.4 and 10.0.2.5)
- Round-robin distribution across both backends
**Important - Cookie-Based Affinity:**
- **If you only see one server:** Cookie-based affinity is enabled (session persistence)
  - Browser sends same cookie each time → always routes to same backend
  - **To see load balancing:** Clear browser cookies, use incognito mode, or use curl
  - **To disable affinity:** See troubleshooting Issue 6 below
  
- **For true round-robin:** Disable cookie-based affinity (recommended for testing)
- **For stateful apps:** Keep affinity enabled (shopping carts, login sessions)
**Important Notes:**
- **Public IP Assignment:** If you didn't use `--public-ip-address ""` during VM creation, VMs will have public IPs
- **Security:** Only the Application Gateway should be publicly accessible, not the backend VMs
- **For Production:** Always use `--public-ip-address ""` when creating backend VMs
- **For Lab/Learning:** You can keep public IPs for easier troubleshooting, but it's not recommended
**If VMs were created with public IPs, remove them:**
```powershell
# Remove public IP from VM1
az network nic ip-config update `
  --resource-group rg-appgw-lab `
  --nic-name vm-web1VMNic `
  --name ipconfigvm-web1 `
  --remove PublicIpAddress
# Remove public IP from VM2
az network nic ip-config update `
  --resource-group rg-appgw-lab `
  --nic-name vm-web2VMNic `
  --name ipconfigvm-web2 `
  --remove PublicIpAddress
# Delete the public IP resources (optional cleanup)
az network public-ip delete --resource-group rg-appgw-lab --name vm-web1PublicIP
az network public-ip delete --resource-group rg-appgw-lab --name vm-web2PublicIP
```
---
### 🔧 Troubleshooting Phase 1
#### Issue 1: VM Size Not Available
**Error:** `SkuNotAvailable: Standard_DS1_v2 is currently not available in location 'CentralIndia'`
**Solution:** Use `--size Standard_B1s` or check available sizes:
```powershell
az vm list-sizes --location centralindia --output table
```
**Recommended VM sizes for Central India (as of Nov 2025):**
- `Standard_B1s` - 1 vCPU, 1 GB RAM (cheapest, good for lab)
- `Standard_B2s` - 2 vCPU, 4 GB RAM
- `Standard_D2s_v3` - 2 vCPU, 8 GB RAM
- `Standard_D2s_v5` - 2 vCPU, 8 GB RAM (newer generation)
#### Issue 2: Cloud-init Didn't Execute
**Symptom:** Accessing VM public IPs shows default nginx page instead of custom content (or can't access VMs if no public IP)
**Solution:** Manually update the index.html files using `az vm run-command`:
```powershell
az vm run-command invoke --resource-group rg-appgw-lab --name vm-web1 --command-id RunShellScript --scripts "echo '<h1>Backend Server 1</h1><p>Hostname: vm-web1</p><p>Private IP: 10.0.2.4</p>' | sudo tee /var/www/html/index.html"
az vm run-command invoke --resource-group rg-appgw-lab --name vm-web2 --command-id RunShellScript --scripts "echo '<h1>Backend Server 2</h1><p>Hostname: vm-web2</p><p>Private IP: 10.0.2.5</p>' | sudo tee /var/www/html/index.html"
```
**Note:** `az vm run-command` works regardless of whether VMs have public IPs or not.
#### Issue 3: VMs Created with Public IPs
**Symptom:** VMs are accessible directly from internet (security risk)
**Root Cause:** Didn't specify `--public-ip-address ""` during VM creation
**Solution:** Remove public IPs from VMs:
```powershell
# Dissociate public IPs from NICs
az network nic ip-config update --resource-group rg-appgw-lab --nic-name vm-web1VMNic --name ipconfigvm-web1 --remove PublicIpAddress
az network nic ip-config update --resource-group rg-appgw-lab --nic-name vm-web2VMNic --name ipconfigvm-web2 --remove PublicIpAddress
# Optional: Delete the public IP resources to avoid charges
az network public-ip delete --resource-group rg-appgw-lab --name vm-web1PublicIP
az network public-ip delete --resource-group rg-appgw-lab --name vm-web2PublicIP
```
#### Issue 4: Routing Rule Priority Error
**Error:** `ApplicationGatewayRequestRoutingRulePriorityCannotBeEmpty`
**Solution:** Add `--priority 100` to the application gateway create command (required for API version 2021-08-01+)
#### Issue 5: Backend Health Check
**Check backend health status:**
```powershell
az network application-gateway show-backend-health --resource-group rg-appgw-lab --name appgw-lab-basic --output table
```
**Common health issues:**
- **Unhealthy backends:** Check NSG rules, verify nginx is running
- **Connection timeout:** Verify backend subnet allows traffic from App Gateway subnet
- **502 errors:** Check if backend VMs are responding on port 80
#### Issue 6: Traffic Only Goes to One Backend Server
**Symptom:** Refreshing browser shows same server every time (only VM1 or only VM2)
**Root Cause:** Cookie-based affinity (session persistence) is enabled
**How it works:**
- Application Gateway sets an `ARRAffinity` cookie on first request
- Browser sends this cookie with every subsequent request
- App Gateway routes all requests with same cookie to same backend server
**Solution - To See Load Balancing:**
```powershell
# Option 1: Disable cookie-based affinity (recommended for testing)
az network application-gateway http-settings update `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --name appGatewayBackendHttpSettings `
  --cookie-based-affinity Disabled
```
**Alternative Testing Methods:**
```powershell
# Option 2: Use curl (doesn't persist cookies)
for ($i=1; $i -le 10; $i++) {
    curl http://74.225.226.223 -UseBasicParsing | Select-String "Backend Server"
}
# Option 3: Clear browser cookies and use incognito mode
# Option 4: Test from different browsers/devices
```
**When to use each setting:**
- **Disabled:** Stateless apps, APIs, microservices, testing load balancing
- **Enabled:** Stateful apps, shopping carts, user sessions, applications requiring session persistence
---
## Phase 2: SSL/TLS & HTTPS (Intermediate)
### Step 4: Generate Self-Signed Certificate
#### 4.1 Generate Certificate (using OpenSSL or PowerShell)
**Option A: Using OpenSSL (WSL or Git Bash)**
```bash
# Generate private key and certificate
openssl req -x509 -newkey rsa:4096 -keyout appgw-key.pem -out appgw-cert.pem -days 365 -nodes -subj "/CN=appgw-lab.local"
# Convert to PFX
openssl pkcs12 -export -out appgw-cert.pfx -inkey appgw-key.pem -in appgw-cert.pem -password pass:YourPassword123
```
**Option B: Using PowerShell**
```powershell
$cert = New-SelfSignedCertificate -DnsName "appgw-lab.local" -CertStoreLocation "Cert:\CurrentUser\My"
$password = ConvertTo-SecureString -String "YourPassword123" -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath "appgw-cert.pfx" -Password $password
```
---
### Step 5: Add HTTPS Listener
#### 5.1 Upload SSL Certificate
```powershell
az network application-gateway ssl-cert create `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --name ssl-cert-lab `
  --cert-file appgw-cert.pfx `
  --cert-password YourPassword123
```
---
#### 5.2 Create HTTPS Frontend Port
```powershell
az network application-gateway frontend-port create `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --name port443 `
  --port 443
```
---
#### 5.3 Create HTTPS Listener
```powershell
az network application-gateway http-listener create `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --name https-listener `
  --frontend-port port443 `
  --ssl-cert ssl-cert-lab
```
---
#### 5.4 Create Routing Rule for HTTPS
```powershell
az network application-gateway rule create `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --name https-rule `
  --http-listener https-listener `
  --rule-type Basic `
  --address-pool appGatewayBackendPool `
  --http-settings appGatewayBackendHttpSettings `
  --priority 100
```
---
### ✅ Test Scenario 2: HTTPS Termination
#### Test Steps:
1. Access via HTTPS: `https://<PUBLIC-IP>`
2. Accept the self-signed certificate warning
3. Verify you can access the site
**Expected Results:**
- HTTPS connection works
- SSL terminates at App Gateway
- Backend still uses HTTP
---
## Phase 3: Multi-Site Hosting (Advanced)
### Step 6: Create Multiple Backend Pools
#### 6.1 Create Backend Pool for App1
```powershell
az network application-gateway address-pool create `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --name pool-app1 `
  --servers $vm1ip
```
---
#### 6.2 Create Backend Pool for App2
```powershell
az network application-gateway address-pool create `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --name pool-app2 `
  --servers $vm2ip
```
---
### Step 7: Configure Multi-Site Listeners
#### 7.1 Create Listener for App1
```powershell
az network application-gateway http-listener create `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --name listener-app1 `
  --frontend-port port443 `
  --host-name app1.yourdomain.com `
  --ssl-cert ssl-cert-lab
```
---
#### 7.2 Create Listener for App2
```powershell
az network application-gateway http-listener create `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --name listener-app2 `
  --frontend-port port443 `
  --host-name app2.yourdomain.com `
  --ssl-cert ssl-cert-lab
```
---
#### 7.3 Create Routing Rules
```powershell
# Rule for App1
az network application-gateway rule create `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --name rule-app1 `
  --http-listener listener-app1 `
  --rule-type Basic `
  --address-pool pool-app1 `
  --http-settings appGatewayBackendHttpSettings `
  --priority 200
# Rule for App2
az network application-gateway rule create `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --name rule-app2 `
  --http-listener listener-app2 `
  --rule-type Basic `
  --address-pool pool-app2 `
  --http-settings appGatewayBackendHttpSettings `
  --priority 201
```
---
### ✅ Test Scenario 3: Host-Based Routing
#### Test Steps:
1. Add entries to your hosts file (`C:\Windows\System32\drivers\etc\hosts`):
   ```
   <PUBLIC-IP>  app1.yourdomain.com
   <PUBLIC-IP>  app2.yourdomain.com
   ```
2. Access:
   - `https://app1.yourdomain.com` → Should route to VM1 (Backend Server 1)
   - `https://app2.yourdomain.com` → Should route to VM2 (Backend Server 2)
**Expected Results:**
- Different backends serve different hostnames
- Each hostname consistently routes to the same backend
---
## Phase 4: Web Application Firewall (WAF)
### Step 8: Upgrade to WAF_v2 SKU
#### 8.1 Stop Application Gateway
```powershell
az network application-gateway stop --resource-group rg-appgw-lab --name appgw-lab-basic
```
---
#### 8.2 Update SKU to WAF_v2
```powershell
az network application-gateway update `
  --resource-group rg-appgw-lab `
  --name appgw-lab-basic `
  --sku WAF_v2 `
  --capacity 2
```
---
#### 8.3 Start Application Gateway
```powershell
az network application-gateway start --resource-group rg-appgw-lab --name appgw-lab-basic
```
---
### Step 9: Enable WAF Policy
#### 9.1 Configure WAF
```powershell
az network application-gateway waf-config set `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --enabled true `
  --firewall-mode Detection `
  --rule-set-type OWASP `
  --rule-set-version 3.2
```
---
### ✅ Test Scenario 4: WAF Protection
#### Test Steps:
1. Try SQL injection:
   ```
   http://<PUBLIC-IP>/?id=1' OR '1'='1
   ```
2. Try XSS:
   ```
   http://<PUBLIC-IP>/?search=<script>alert('XSS')</script>
   ```
3. Try path traversal:
   ```
   http://<PUBLIC-IP>/../../../etc/passwd
   ```
4. Check WAF logs:
   ```powershell
   az monitor activity-log list --resource-group rg-appgw-lab --offset 1h
   ```
**Expected Results:**
- Malicious requests are logged (Detection mode) or blocked (Prevention mode)
- WAF logs show triggered rules
---
## Phase 5: Advanced Routing & Rewrite Rules
### Step 10: Path-Based Routing
#### 10.1 Create URL Path Map
```powershell
# Create URL path map with multiple path rules
az network application-gateway url-path-map create `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --name path-map-basic `
  --paths /images/* `
  --address-pool pool-app1 `
  --http-settings appGatewayBackendHttpSettings `
  --default-address-pool appGatewayBackendPool `
  --default-http-settings appGatewayBackendHttpSettings
```
**Expected Output:**
- URL path map created: `path-map-basic`
- Default pool: `appGatewayBackendPool` (for paths not matching rules)
- Path rule: `/images/*` → `pool-app1` (VM1)
---
#### 10.2 Add Additional Path Rule for Videos
```powershell
# Add /videos/* path to route to VM2
az network application-gateway url-path-map rule create `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --path-map-name path-map-basic `
  --name videos-rule `
  --paths /videos/* `
  --address-pool pool-app2 `
  --http-settings appGatewayBackendHttpSettings
```
**Expected Output:**
- New path rule added: `/videos/*` → `pool-app2` (VM2)
- Now have 2 path-based rules + default pool
---
#### 10.3 Update HTTPS Rule to Use Path-Based Routing
```powershell
# Update existing https-rule to use path-based routing
az network application-gateway rule update `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --name https-rule `
  --rule-type PathBasedRouting `
  --url-path-map path-map-basic
```
**Expected Output:**
- Rule type changed from `Basic` to `PathBasedRouting`
- HTTPS traffic now routes based on URL path:
  - `/images/*` → VM1 (10.0.2.4)
  - `/videos/*` → VM2 (10.0.2.5)
  - Other paths → Round-robin both VMs
---
### Step 11: Header Rewrite Rules
#### 11.1 Create Rewrite Rule Set
```powershell
# Create rewrite rule set for security headers
az network application-gateway rewrite-rule set create `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --name security-headers-rewrite
```
**Expected Output:**
- Rewrite rule set created: `security-headers-rewrite`
---
#### 11.2 Add Security Headers
```powershell
# Add security headers to all responses
az network application-gateway rewrite-rule create `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --rule-set-name security-headers-rewrite `
  --name add-security-headers `
  --response-headers X-Content-Type-Options=nosniff X-Frame-Options=SAMEORIGIN Strict-Transport-Security="max-age=31536000; includeSubDomains"
```
**Expected Output:**
- Rewrite rule created with 3 security headers:
  - `X-Content-Type-Options: nosniff` (prevents MIME sniffing)
  - `X-Frame-Options: SAMEORIGIN` (prevents clickjacking)
  - `Strict-Transport-Security: max-age=31536000; includeSubDomains` (enforces HTTPS)
---
#### 11.3 Associate Rewrite Rule with Routing Rule
```powershell
# Apply rewrite rules to HTTPS traffic
az network application-gateway rule update `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --name https-rule `
  --rewrite-rule-set security-headers-rewrite
```
**Expected Output:**
- Rewrite rule set associated with `https-rule`
- All HTTPS responses now include security headers
---
### ✅ Test Scenario 5: Advanced Routing
#### Test Steps (from another machine):
1. **Test path-based routing to /images/***:
   ```bash
   curl -k https://74.225.226.223/images/test.jpg
   ```
   Should route to pool-app1 (VM1 - 10.0.2.4)
2. **Test path-based routing to /videos/***:
   ```bash
   curl -k https://74.225.226.223/videos/test.mp4
   ```
   Should route to pool-app2 (VM2 - 10.0.2.5)
3. **Test default path (root or other paths)**:
   ```bash
   curl -k https://74.225.226.223/
   curl -k https://74.225.226.223/api/test
   ```
   Should use round-robin to appGatewayBackendPool (both VMs)
4. **Check security headers in response**:
   ```bash
   curl -kI https://74.225.226.223/
   # Or with verbose output
   curl -kv https://74.225.226.223/
   ```
**Expected Results:**
- `/images/*` consistently routes to VM1
- `/videos/*` consistently routes to VM2
- Other paths load balance between both VMs
- Security headers present in all responses:
  - `X-Content-Type-Options: nosniff`
  - `X-Frame-Options: SAMEORIGIN`
  - `Strict-Transport-Security: max-age=31536000; includeSubDomains`
**Verify in Log Analytics:**
```kql
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where requestUri_s contains "/images/" or requestUri_s contains "/videos/"
| project TimeGenerated, requestUri_s, serverRouted_s
| order by TimeGenerated desc
```
---
## Phase 6: Monitoring & Troubleshooting
### Step 12: Enable Diagnostics
#### 12.1 Create Log Analytics Workspace
```powershell
az monitor log-analytics workspace create `
  --resource-group rg-appgw-lab `
  --workspace-name law-appgw-lab `
  --location centralindia
```
**Expected Output:** 
- Workspace ID: `3a5f499f-d4bb-4287-9e1d-7b07e3a696ab`
- Retention: 30 days
- SKU: PerGB2018
---
#### 12.2 Enable Diagnostic Settings
```powershell
az monitor diagnostic-settings create `
  --name appgw-diagnostics `
  --resource /subscriptions/c00e6e52-e8c3-4cbb-a254-d028bfb0a769/resourceGroups/rg-appgw-lab/providers/Microsoft.Network/applicationGateways/appgw-lab-basic `
  --workspace /subscriptions/c00e6e52-e8c3-4cbb-a254-d028bfb0a769/resourceGroups/rg-appgw-lab/providers/Microsoft.OperationalInsights/workspaces/law-appgw-lab `
  --logs '[{\"category\":\"ApplicationGatewayAccessLog\",\"enabled\":true},{\"category\":\"ApplicationGatewayPerformanceLog\",\"enabled\":true},{\"category\":\"ApplicationGatewayFirewallLog\",\"enabled\":true}]' `
  --metrics '[{\"category\":\"AllMetrics\",\"enabled\":true}]'
```
**Note:** Logs take 5-15 minutes to start appearing in Log Analytics after enabling diagnostic settings.
---
### ✅ Test Scenario 6: Monitoring & Log Analytics
#### Test Steps:
1. **Generate test traffic** (access the site multiple times via HTTP and HTTPS)
2. **Wait 5-15 minutes** for logs to populate
3. **Query Access Logs (View Recent Requests):**
   ```powershell
   az monitor log-analytics query --workspace 3a5f499f-d4bb-4287-9e1d-7b07e3a696ab --analytics-query "AzureDiagnostics | where ResourceType == 'APPLICATIONGATEWAYS' and Category == 'ApplicationGatewayAccessLog' | where TimeGenerated > ago(1h) | project TimeGenerated, ClientIP=clientIP_s, OrigHost=originalHost_s, Method=httpMethod_s, URI=requestUri_s, Status=httpStatus_d, BackendServer=serverRouted_s, ResponseTime=timeTaken_d, SSL=sslProtocol_s, Rule=ruleName_s | order by TimeGenerated desc | take 15" --output table
   ```
4. **Query Load Balancing Distribution:**
   ```powershell
   az monitor log-analytics query --workspace 3a5f499f-d4bb-4287-9e1d-7b07e3a696ab --analytics-query "AzureDiagnostics | where ResourceType == 'APPLICATIONGATEWAYS' and Category == 'ApplicationGatewayAccessLog' | where TimeGenerated > ago(1h) | summarize Requests=count(), AvgResponseTime=avg(timeTaken_d), MaxResponseTime=max(timeTaken_d) by serverRouted_s" --output table
   ```
5. **Query HTTP Status Distribution:**
   ```powershell
   az monitor log-analytics query --workspace 3a5f499f-d4bb-4287-9e1d-7b07e3a696ab --analytics-query "AzureDiagnostics | where ResourceType == 'APPLICATIONGATEWAYS' and Category == 'ApplicationGatewayAccessLog' | where TimeGenerated > ago(1h) | summarize Requests=count() by httpStatus_d, ruleName_s | order by Requests desc" --output table
   ```
6. **Check metrics in Azure Portal:**
   - Navigate to Application Gateway → Metrics
   - View: Total Requests, Failed Requests, Backend Response Time, Healthy Host Count
**Expected Results:**
- ✅ Access logs show detailed request information:
  - **Client IPs** - Who made the request
  - **Request URIs** - What was requested
  - **HTTP Status** - Response codes (200, 404, etc.)
  - **Backend Server** - Which VM handled it (10.0.2.4 or 10.0.2.5)
  - **Response Time** - How long it took (milliseconds)
  - **SSL Protocol** - TLSv1.3 for HTTPS, blank for HTTP
  - **Rule Name** - Which routing rule was used
- ✅ Load balancing shows ~50/50 distribution between VMs
- ✅ Performance metrics show response times (typically 1-4ms)
- ✅ Can track all requests by IP, time, and outcome
**Sample Log Analytics Findings:**
```
Load Distribution:
- VM1 (10.0.2.4): 42 requests, avg 1.7ms
- VM2 (10.0.2.5): 41 requests, avg 3.1ms
HTTP Status Breakdown:
- 200 (Success): 79 requests (66 HTTPS, 13 HTTP)
- 404 (Not Found): 3 requests
- 304 (Not Modified): 1 request
```
---
### Useful KQL Queries for Application Gateway
#### 1. Top Client IPs
```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS" and Category == "ApplicationGatewayAccessLog"
| where TimeGenerated > ago(24h)
| summarize RequestCount=count() by clientIP_s
| order by RequestCount desc
| take 10
```
#### 2. Slow Requests (>100ms)
```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS" and Category == "ApplicationGatewayAccessLog"
| where TimeGenerated > ago(1h)
| where timeTaken_d > 0.1
| project TimeGenerated, clientIP_s, requestUri_s, httpStatus_d, timeTaken_d, serverRouted_s
| order by timeTaken_d desc
```
#### 3. Error Tracking (4xx and 5xx)
```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS" and Category == "ApplicationGatewayAccessLog"
| where TimeGenerated > ago(1h)
| where httpStatus_d >= 400
| summarize ErrorCount=count() by httpStatus_d, requestUri_s
| order by ErrorCount desc
```
#### 4. SSL/TLS Protocol Distribution
```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS" and Category == "ApplicationGatewayAccessLog"
| where TimeGenerated > ago(1h)
| where isnotempty(sslProtocol_s)
| summarize count() by sslProtocol_s
```
#### 5. Backend Health Over Time
```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS" and Category == "ApplicationGatewayPerformanceLog"
| where TimeGenerated > ago(1h)
| summarize avg(healthyHostCount_d), avg(unhealthyHostCount_d) by bin(TimeGenerated, 5m)
| render timechart
```
---
## Phase 7: Health Probes & Session Affinity
### Step 13: Custom Health Probes
#### 13.1 Create Custom Health Probe
```powershell
# Create HTTP health probe to check backend health
az network application-gateway probe create `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --name health-probe-custom `
  --protocol Http `
  --host-name-from-http-settings false `
  --host 127.0.0.1 `
  --path / `
  --interval 30 `
  --timeout 30 `
  --threshold 3
```
**Expected Output:**
- Health probe created: `health-probe-custom`
- Protocol: HTTP
- Path: `/` (checks root path)
- Interval: 30 seconds (probe frequency)
- Timeout: 30 seconds (probe timeout)
- Unhealthy threshold: 3 consecutive failures
- Status codes: 200-399 (considered healthy)
**What it does:**
- Sends HTTP GET request to `http://127.0.0.1/` on each backend every 30 seconds
- If backend responds with 200-399 status code → Healthy
- If 3 consecutive probes fail → Backend marked unhealthy (traffic stops routing there)
---
#### 13.2 Update Backend HTTP Settings with Health Probe and Session Affinity
```powershell
# Enable custom health probe and cookie-based session affinity
az network application-gateway http-settings update `
  --resource-group rg-appgw-lab `
  --gateway-name appgw-lab-basic `
  --name appGatewayBackendHttpSettings `
  --probe health-probe-custom `
  --cookie-based-affinity Enabled `
  --affinity-cookie-name AppGatewayAffinity
```
**Expected Output:**
- Health probe associated: `health-probe-custom`
- Cookie-based affinity: `Enabled`
- Affinity cookie name: `AppGatewayAffinity`
**What it does:**
- Uses custom health probe to monitor backend health
- Sets `AppGatewayAffinity` cookie in HTTP responses
- Subsequent requests with this cookie route to same backend server
- Enables session persistence for stateful applications
---
#### 13.3 Check Backend Health Status
```powershell
# Verify both backends are healthy
az network application-gateway show-backend-health `
  --resource-group rg-appgw-lab `
  --name appgw-lab-basic `
  --query "backendAddressPools[].backendHttpSettingsCollection[].servers[].{Address:address, Health:health, HealthProbeLog:healthProbeLog}" `
  --output table
```
**Expected Output:**
```
Address    Health    HealthProbeLog
---------  --------  ---------------------------------
10.0.2.4   Healthy   Success. Received 200 status code
10.0.2.5   Healthy   Success. Received 200 status code
```
---
### ✅ Test Scenario 7: Health Monitoring & Session Affinity
#### Test Steps (from another machine):
**Part 1: Test Session Affinity (Cookie-Based Persistence)**
1. **Make requests and save cookies**:
   ```bash
   # First request - Application Gateway sets AppGatewayAffinity cookie
   curl -k -c cookies.txt https://74.225.226.223/
   
   # View the cookie file
   cat cookies.txt
   ```
2. **Make multiple requests WITH cookie** (should stick to same backend):
   ```bash
   curl -k -b cookies.txt https://74.225.226.223/
   curl -k -b cookies.txt https://74.225.226.223/
   curl -k -b cookies.txt https://74.225.226.223/
   # All should route to the SAME backend server
   ```
3. **Make requests WITHOUT cookie** (load balanced):
   ```bash
   curl -k https://74.225.226.223/
   curl -k https://74.225.226.223/
   curl -k https://74.225.226.223/
   # May route to DIFFERENT backend servers
   ```
4. **See the affinity cookie in response headers**:
   ```bash
   curl -kv https://74.225.226.223/ 2>&1 | grep -i "set-cookie"
   # Should see: Set-Cookie: AppGatewayAffinity=...
   ```
**Expected Results:**
- ✅ First response includes `Set-Cookie: AppGatewayAffinity=<hash>`
- ✅ Subsequent requests WITH cookie route to same backend consistently
- ✅ Requests WITHOUT cookie may be load-balanced across backends
---
**Part 2: Test Health Probe**
1. **Verify current backend health**:
   ```powershell
   az network application-gateway show-backend-health `
     --resource-group rg-appgw-lab `
     --name appgw-lab-basic `
     --query "backendAddressPools[].backendHttpSettingsCollection[].servers[].{Address:address, Health:health}" `
     --output table
   ```
   Expected: Both backends showing "Healthy"
2. **Optional: Simulate backend failure** (stop nginx on VM1):
   ```powershell
   az vm run-command invoke `
     --resource-group rg-appgw-lab `
     --name vm-web1 `
     --command-id RunShellScript `
     --scripts "sudo systemctl stop nginx"
   ```
3. **Wait 2-3 minutes** (for 3 health probe failures at 30-second intervals)
4. **Check backend health again**:
   ```powershell
   az network application-gateway show-backend-health `
     --resource-group rg-appgw-lab `
     --name appgw-lab-basic `
     --output table
   ```
   Expected: VM1 should show "Unhealthy"
5. **Test traffic** - all requests should only go to VM2:
   ```bash
   curl -k https://74.225.226.223/
   ```
6. **Restore VM1** (if stopped):
   ```powershell
   az vm run-command invoke `
     --resource-group rg-appgw-lab `
     --name vm-web1 `
     --command-id RunShellScript `
     --scripts "sudo systemctl start nginx"
   ```
**Expected Results:**
- ✅ Unhealthy backends automatically removed from rotation
- ✅ Traffic only routes to healthy backends
- ✅ Backend automatically restored when health probe succeeds
- ✅ Zero downtime during backend failure (other backend handles traffic)
---
## Comprehensive Testing Checklist
| # | Scenario | What to Test | Expected Outcome | Status |
|---|----------|--------------|------------------|--------|
| 1 | Basic Load Balancing | Access public IP 10 times | Traffic alternates between backends | ☐ |
| 2 | SSL Termination | Access via HTTPS | SSL terminates at App GW, backend uses HTTP | ☐ |
| 3 | Multi-Site Hosting | Use different hostnames | Different backends serve different apps | ☐ |
| 4 | WAF Protection | Try SQL injection, XSS | Requests blocked/logged by WAF | ☐ |
| 5 | Path-Based Routing | Access `/api/*` vs `/web/*` | Different backends based on path | ☐ |
| 6 | Session Affinity | Login and refresh page | Same backend serves all requests in session | ☐ |
| 7 | Health Probes | Stop backend service | App GW stops routing to unhealthy backend | ☐ |
| 8 | Autoscaling | Generate high traffic | Instance count increases automatically | ☐ |
| 9 | Custom Error Pages | Access non-existent page | Custom 404 page displayed | ☐ |
| 10 | Header Rewrite | Check response headers | Security headers added by App GW | ☐ |
---
## Learning Resources
### Official Documentation
- [Azure Application Gateway Overview](https://learn.microsoft.com/en-us/azure/application-gateway/)
- [App Gateway Components](https://learn.microsoft.com/en-us/azure/application-gateway/application-gateway-components)
- [Backend Health Diagnostics](https://learn.microsoft.com/en-us/azure/application-gateway/application-gateway-backend-health-troubleshooting)
### WAF Resources
- [WAF Overview](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/ag-overview)
- [OWASP Core Rule Set](https://owasp.org/www-project-modsecurity-core-rule-set/)
- [WAF Tuning](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/application-gateway-crs-rulegroups-rules)
### Troubleshooting
- [Common Issues](https://learn.microsoft.com/en-us/azure/application-gateway/application-gateway-troubleshooting-502)
- [Backend Health FAQ](https://learn.microsoft.com/en-us/azure/application-gateway/application-gateway-faq-backend-health)
- [Performance Tuning](https://learn.microsoft.com/en-us/azure/application-gateway/application-gateway-performance)
---
## Pro Tips
### 💡 Best Practices
1. **Use NSGs carefully** - Allow HTTP/HTTPS from App GW subnet to backend subnet
2. **Monitor costs** - WAF_v2 is more expensive than Standard_v2
3. **Test failover** - Intentionally break backends to see App GW behavior
4. **Use Terraform** - Once comfortable, recreate entire setup with IaC
5. **Practice troubleshooting** - Break things intentionally and fix them
### 🔍 Troubleshooting Tips
- **502 Bad Gateway?** → Check backend health and NSG rules
- **Backend unhealthy?** → Verify health probe path and port
- **SSL issues?** → Check certificate validity and SNI configuration
- **WAF blocking legitimate traffic?** → Review and tune WAF rules
- **Performance issues?** → Check backend response times and instance count
### 📊 Monitoring Best Practices
- Enable diagnostics from day one
- Set up alerts for unhealthy backends
- Monitor backend response time trends
- Track WAF block/detect counts
- Use Log Analytics for deep analysis
---
## Cleanup
### Remove All Resources
⚠️ **Warning:** This will delete everything created in this lab!
```powershell
# Delete resource group and all resources
az group delete --name rg-appgw-lab --yes --no-wait
# Verify deletion
az group list --query "[?name=='rg-appgw-lab']" --output table
```
---
## Next Steps
After completing this lab, you can:
1. **Recreate with Terraform** - Use IaC to automate the entire setup
2. **Integrate with Azure Front Door** - Create a global load balancing solution
3. **Add Private Link** - Secure backend connectivity
4. **Implement mTLS** - Mutual TLS authentication
5. **Practice DR scenarios** - Multi-region App Gateway setup
---
## Notes & Observations
Use this space to document your learnings:
- [x] Challenges encountered:
  - VM size Standard_DS1_v2 not available in Central India - switched to Standard_B1s ✅
  - Cloud-init script didn't execute automatically - had to manually configure VMs using `az vm run-command` ✅
  - Routing rule priority parameter required in newer API versions (2021-08-01+) ✅
  - VMs created with public IPs by default - removed them after deployment for production security ✅
  - Cookie-based affinity caused sticky sessions - disabled to see true round-robin load balancing ✅
  - PowerShell 5.1 doesn't support `-SkipCertificateCheck` for HTTPS testing - used alternative methods ✅
- [x] Key takeaways:
  - Application Gateway public IP: 74.225.226.223 (only public-facing component) ✅
  - VM1 private IP: 10.0.2.4 (no public IP - secure!) ✅
  - VM2 private IP: 10.0.2.5 (no public IP - secure!) ✅
  - Cookie-based affinity initially enabled (caused sticky sessions) - disabled for round-robin ✅
  - Load balancing works successfully - confirmed traffic alternating between both backend servers ✅
  - `az vm run-command` is essential for managing VMs without public IPs ✅
  - SSL/TLS certificate created and uploaded successfully (self-signed for lab) ✅
  - HTTPS (port 443) configured alongside HTTP (port 80) - both working ✅
  - SSL termination happens at Application Gateway - backends use HTTP for efficiency ✅
  - Backend health monitoring shows both servers healthy with 200 status codes ✅
  - Processed 340+ requests through Application Gateway successfully ✅
  - **Log Analytics workspace is MANDATORY for detailed request logging** ✅
  - **Azure Monitor Metrics only show aggregated numbers (not individual requests)** ✅
  - **Diagnostic settings take 5-15 minutes for initial log population** ✅
  - **Access logs provide complete visibility: client IPs, URIs, response codes, backend servers, response times** ✅
  - **KQL queries enable powerful log analysis and troubleshooting** ✅
  - **Load distribution verified through logs: 42 requests to VM1, 41 to VM2 (perfect balance!)** ✅
  - **Response times typically 1-4ms (very fast with current setup)** ✅
  - **KQL queries ONLY work with Log Analytics - Storage Account only stores JSON files (no query interface)** ✅
  - **Application Gateway access logs don't capture request headers/cookies/body - only connection metadata** ✅
  - **Nginx logs on VMs show App Gateway IPs (10.0.1.4/10.0.1.5) not original client IPs** ✅
  - **Can view logs in Azure Portal: App Gateway → Logs OR Log Analytics Workspace → Logs** ✅
  - **Reduced App Gateway from 2 instances to 1 instance = 50% cost savings (~$88/month)** ✅
- [ ] Questions for further research:
  - Best practices for VM sizing in production Application Gateway deployments
  - NSG rules optimization for App Gateway and backend subnets
  - Cost comparison between Standard_v2 and WAF_v2 SKUs
  - Autoscaling configuration and triggers (min/max instances)
  - Certificate management for production (Key Vault integration, renewal automation)
  - ~~How to view detailed access logs and query patterns in Log Analytics~~ ✅ COMPLETED
  - Performance benchmarking: requests per second capacity of Standard_v2
  - Log retention policies and cost optimization for Log Analytics
  - Setting up alerts based on log queries (e.g., high error rates, slow responses)
  - Integrating Application Gateway logs with Azure Sentinel for security monitoring
  - ~~Difference between Log Analytics vs Storage Account for diagnostic logs~~ ✅ COMPLETED
  - ~~How to view nginx logs on VMs without public IPs~~ ✅ COMPLETED
  - ~~Cost optimization: reducing Application Gateway instances~~ ✅ COMPLETED
---
**Monitoring & Verification:**
- **Backend Health:** Both servers healthy (verified via CLI and available in Azure Portal)
- **Metrics Available:** Total Requests, Failed Requests, Healthy Host Count, Backend Response Time
- **Total Traffic Processed:** 340+ requests successfully routed through Application Gateway
- **Configuration Verified:** 2 frontend ports (80, 443), 2 listeners (HTTP, HTTPS), 2 routing rules
- **Instance Count:** Reduced from 2 to 1 instance (50% cost savings = ~$88/month)
- **Log Analytics:**
  - Workspace: law-appgw-lab (3a5f499f-d4bb-4287-9e1d-7b07e3a696ab)
  - Access logs enabled and verified working
  - 83+ requests logged with full details (client IP, URI, status, backend server, response time)
  - Load distribution: VM1: 42 requests, VM2: 41 requests
  - Response time range: 0.001 - 0.036 seconds (1-36ms)
  - Success rate: 95% (79/83 requests returned 200 OK)
  - Portal access: App Gateway → Logs OR Log Analytics Workspace → Logs
  - KQL queries available (only with Log Analytics, not Storage Account)
- **Nginx Logs on VMs:**
  - Location: /var/log/nginx/access.log and /var/log/nginx/error.log
  - Access method: `az vm run-command invoke` (since no public IPs)
  - Shows App Gateway internal IPs (10.0.1.4) not original client IPs
  - Useful for backend debugging, not client tracking
---
**Lab Execution Details:**
- **Date:** November 12, 2025
- **Location:** Central India
- **VM Size Used:** Standard_B1s
- **App Gateway SKU:** Standard_v2
- **App Gateway Instances:** 1 (reduced from 2 for cost savings)
- **Estimated Monthly Cost:** ~$89/month for App Gateway + ~$20/month for VMs + ~$5/month for Log Analytics = **~$114/month total**
- **Phase 1 Status:** ✅ Completed & Tested Successfully
  - Infrastructure created (VNet, Subnets, Public IP)
  - Backend VMs deployed without public IPs (security best practice)
  - HTTP load balancing verified and working
  - Cookie-based affinity disabled for round-robin distribution
- **Phase 2 Status:** ✅ Completed & Tested Successfully
  - Self-signed SSL certificate generated (appgw-cert.pfx)
  - HTTPS listener configured on port 443
  - SSL/TLS termination working at Application Gateway
  - Both HTTP (80) and HTTPS (443) working simultaneously
  - Backend health: Both servers healthy (10.0.2.4, 10.0.2.5)
- **Phase 3 Status:** ✅ Completed & Tested Successfully
  - Separate backend pools created for each application:
    * pool-app1 → VM1 (10.0.2.4)
    * pool-app2 → VM2 (10.0.2.5)
  - Multi-site HTTPS listeners configured with SNI:
    * listener-app1: app1.appgwlab.local (requireServerNameIndication: true)
    * listener-app2: app2.appgwlab.local (requireServerNameIndication: true)
  - Host-based routing rules created:
    * rule-app1 (priority 300): app1.appgwlab.local → pool-app1
    * rule-app2 (priority 400): app2.appgwlab.local → pool-app2
  - Multi-site routing tested and verified working:
    * app1.appgwlab.local correctly routes to VM1
    * app2.appgwlab.local correctly routes to VM2
  - Single Application Gateway (74.225.226.223) now serving multiple applications with hostname-based routing
  - Total routing rules: 4 (HTTP, HTTPS catch-all, app1, app2) with priorities 100, 200, 300, 400
- **Phase 4 Status:** ⏳ Pending (WAF)
- **Phase 5 Status:** ✅ Completed & Tested Successfully
  - URL path map created (path-map-basic) with path-based routing:
    * /images/* → pool-app1 (VM1)
    * /videos/* → pool-app2 (VM2)
    * Default path (/*) → appGatewayBackendPool (both VMs)
  - HTTPS routing rule updated to use path-based routing instead of basic routing
  - Header rewrite rule set created (security-headers-rewrite):
    * X-Content-Type-Options: nosniff (prevents MIME sniffing attacks)
    * X-Frame-Options: SAMEORIGIN (prevents clickjacking)
    * Strict-Transport-Security: max-age=31536000; includeSubDomains (enforces HTTPS)
  - Rewrite rules associated with https-rule (applies to all HTTPS traffic)
  - Path-based routing tested and verified working:
    * /images/* correctly routes to VM1
    * /videos/* correctly routes to VM2
    * Other paths use round-robin across both VMs
  - Security headers verified in HTTP responses
  - Advanced routing demonstrates sophisticated traffic management capabilities
- **Phase 6 Status:** ✅ Completed & Tested Successfully
  - Log Analytics workspace created (law-appgw-lab)
  - Workspace ID: 3a5f499f-d4bb-4287-9e1d-7b07e3a696ab
  - Diagnostic settings enabled (Access Logs, Performance Logs, Firewall Logs, Metrics)
  - Access logs flowing successfully (5-15 min initial delay)
  - Detailed request visibility achieved:
    * Client IP addresses tracked
    * Request URIs and HTTP methods logged
    * Response codes and times recorded
    * Backend server routing visible (10.0.2.4 vs 10.0.2.5)
    * SSL/TLS protocol versions captured (TLSv1.3)
  - Load balancing metrics verified (42 requests to VM1, 41 to VM2)
  - Average response time: 1-4ms per request
  - Total logged requests: 83+ (79 success, 3 not found, 1 not modified)
  - KQL query library documented for common scenarios
  - Portal navigation verified: App Gateway → Logs and Log Analytics Workspace → Logs
  - Explored log destination options (Log Analytics vs Storage Account vs Event Hub)
  - Verified nginx logs on VMs using `az vm run-command`
  - Understood limitations: App Gateway logs don't capture headers/cookies/body
  - Cost optimization: Reduced instances from 2 to 1 (50% savings)
- **Phase 7 Status:** ✅ Completed & Tested Successfully
  - Custom health probe created (health-probe-custom):
    * Protocol: HTTP
    * Path: /
    * Interval: 30 seconds
    * Timeout: 30 seconds
    * Unhealthy threshold: 3 consecutive failures
    * Host: 127.0.0.1
  - Health probe associated with backend HTTP settings (appGatewayBackendHttpSettings)
  - Backend health status verified: Both VMs healthy (200 OK responses)
  - Cookie-based session affinity enabled:
    * Cookie name: AppGatewayAffinity
    * Affinity setting: Enabled
    * Ensures subsequent requests from same client route to same backend server
  - Session affinity tested and verified working:
    * Requests with affinity cookie consistently route to same backend
    * Requests without cookie are load-balanced across backends
    * AppGatewayAffinity cookie set in response headers
  - Health probe ensures only healthy backends receive traffic
  - Session persistence improves user experience for stateful applications
---
**Good luck with your Application Gateway learning journey! 🚀**
*Last Updated: November 12, 2025*
<img width="784" height="22039" alt="image" src="https://github.com/user-attachments/assets/cb059e6a-a400-4ad3-bf4a-449977213de7" />
