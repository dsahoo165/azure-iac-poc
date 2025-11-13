# Azure Load Balancer Guide

## Overview
This guide explains Azure Load Balancer concepts and how it differs from Application Gateway and Azure Front Door.

## What is Azure Load Balancer?

Azure Load Balancer is a **Layer 4 (Transport Layer)** load balancing service that distributes network traffic across multiple backend resources. It operates at the TCP/UDP level and doesn't inspect application-layer content.

### Key Characteristics
- **Protocol**: TCP and UDP traffic
- **Layer**: OSI Layer 4 (Transport)
- **Scope**: Regional (within a single Azure region)
- **Cost**: Lower cost compared to Application Gateway
- **Use Case**: Non-HTTP workloads, simple HTTP load balancing

## Load Balancer vs Application Gateway vs Front Door

| Feature | Load Balancer | Application Gateway | Front Door |
|---------|--------------|---------------------|------------|
| **OSI Layer** | Layer 4 (TCP/UDP) | Layer 7 (HTTP/HTTPS) | Layer 7 (HTTP/HTTPS) |
| **Scope** | Regional | Regional | Global |
| **Protocol** | Any TCP/UDP | HTTP/HTTPS | HTTP/HTTPS |
| **SSL Termination** | ❌ No | ✅ Yes | ✅ Yes |
| **URL Routing** | ❌ No | ✅ Yes | ✅ Yes |
| **WAF** | ❌ No | ✅ Yes | ✅ Yes |
| **Cookie Affinity** | Hash-based | ✅ Yes | ✅ Yes |
| **Health Probes** | TCP/HTTP/HTTPS | HTTP/HTTPS | HTTP/HTTPS |
| **Cost** | $ | $$ | $$$ |
| **Best For** | Non-HTTP apps, simple scenarios | Regional web apps, advanced routing | Global apps, CDN, geo-redundancy |

## Architecture Components

### 1. **Frontend IP Configuration**
- Public or private IP address that receives incoming traffic
- Standard SKU supports both public and private IPs simultaneously
- Can have multiple frontend IPs

### 2. **Backend Pool**
- Collection of VM NICs, VM Scale Sets, or IP addresses
- Traffic is distributed across healthy backends
- Supports cross-region backends (Standard SKU with Gateway LB)

### 3. **Health Probes**
- **TCP Probe**: Checks if port is listening
- **HTTP Probe**: Checks for HTTP 200 response
- **HTTPS Probe**: Checks HTTPS endpoint
- Configurable interval and unhealthy threshold

### 4. **Load Balancing Rules**
- Define how traffic flows from frontend to backend
- Map frontend port to backend port
- Protocol (TCP/UDP)
- Session persistence (hash distribution)

### 5. **Inbound NAT Rules**
- Direct port forwarding to specific backend VMs
- Example: SSH access to individual VMs
- Port mapping (e.g., public port 2201 → VM1 port 22)

### 6. **Outbound Rules**
- Configure Source NAT (SNAT) for outbound connectivity
- Control how backend VMs access the internet
- Prevent SNAT port exhaustion

## Load Balancer SKUs

### Basic SKU (Deprecated)
- ⚠️ Will be retired September 30, 2025
- Limited features
- Free tier
- Not recommended for production

### Standard SKU (Recommended)
- **Zone redundancy** - Survives zone failures
- **Secure by default** - Closed to inbound traffic unless allowed by NSG
- **SLA** - 99.99% availability SLA
- **Larger backend pool** - Up to 1000 instances
- **HA Ports** - Load balance all ports
- **Multiple frontend IPs**
- **Outbound rules** - Control SNAT behavior
- **Metrics and diagnostics** - Azure Monitor integration

## Distribution Modes

### 1. **Default (5-tuple hash)**
- Source IP, Source Port, Destination IP, Destination Port, Protocol
- Best distribution across backends
- Each new connection can go to different backend

### 2. **Source IP (2-tuple hash)**
- Source IP, Destination IP
- Same client always goes to same backend
- Use for session affinity requirements

### 3. **Source IP and Protocol (3-tuple hash)**
- Source IP, Destination IP, Protocol
- Similar to Source IP but protocol-aware

## Health Probes Deep Dive

### TCP Probe
```hcl
resource "azurerm_lb_probe" "tcp_probe" {
  protocol            = "Tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}
```
- Establishes TCP connection
- Successful if connection established
- Use when HTTP check not available

### HTTP/HTTPS Probe
```hcl
resource "azurerm_lb_probe" "http_probe" {
  protocol            = "Http"
  port                = 80
  request_path        = "/health"
  interval_in_seconds = 5
  number_of_probes    = 2
}
```
- Sends HTTP GET request
- Expects 200 OK response
- More application-aware than TCP

### Probe Behavior
- **Interval**: Time between probes (5-2147483646 seconds)
- **Number of probes**: Consecutive failures before marking unhealthy
- **Unhealthy threshold** = Interval × Number of probes

Example: interval=5, probes=2 → VM marked unhealthy after 10 seconds

## Common Use Cases

### 1. Internal Line-of-Business Apps
```
Internet → Application Gateway → Load Balancer → Backend VMs
```
- App Gateway handles SSL, WAF, URL routing
- Load Balancer distributes to app tier

### 2. Non-HTTP Services
- SQL Server databases
- Redis cache clusters
- Custom TCP/UDP applications
- Gaming servers (UDP)
- LDAP, DNS, SMTP services

### 3. Hybrid Architecture
```
On-Premises → ExpressRoute → Load Balancer → Azure VMs
```
- Private Load Balancer for hybrid scenarios
- No public internet exposure

### 4. Outbound Internet Access
```
Backend VMs (no public IP) → Outbound Rule → Load Balancer Public IP → Internet
```
- Controlled outbound connectivity
- Shared public IP for multiple VMs

## Configuration Examples

### High Availability Setup
```hcl
# Standard LB with zone redundancy
resource "azurerm_public_ip" "lb_pip" {
  sku               = "Standard"
  availability_zone = "Zone-Redundant"
}

# Distribute VMs across availability zones
resource "azurerm_linux_virtual_machine" "vm" {
  zone = "1"  # or "2", "3"
}
```

### Session Persistence
```hcl
resource "azurerm_lb_rule" "persistent_rule" {
  load_distribution = "SourceIP"  # Session affinity
}
```

### HA Ports (All Ports)
```hcl
resource "azurerm_lb_rule" "ha_ports" {
  protocol      = "All"
  frontend_port = 0
  backend_port  = 0
}
```

## Deployment Steps

### 1. Plan Your Configuration
```bash
terraform plan -out=lb.tfplan
```

### 2. Apply Configuration
```bash
terraform apply lb.tfplan
```

### 3. Verify Deployment
```bash
# Get Load Balancer details
az network lb show \
  --resource-group rg-appgw-lab \
  --name lb-web-basic \
  --output table

# Check backend health
az network lb show-backend-health \
  --resource-group rg-appgw-lab \
  --name lb-web-basic \
  --output table
```

### 4. Test Connectivity
```bash
# Test HTTP endpoint
curl http://<LB_PUBLIC_IP>

# Test with multiple requests to see distribution
for i in {1..10}; do curl http://<LB_PUBLIC_IP>; echo ""; done

# SSH to VM1 via NAT rule
ssh -p 2201 azureuser@<LB_PUBLIC_IP>

# SSH to VM2 via NAT rule
ssh -p 2202 azureuser@<LB_PUBLIC_IP>
```

## Monitoring and Troubleshooting

### Key Metrics
1. **Data Path Availability** - Frontend-to-backend connectivity
2. **Health Probe Status** - Backend health check results
3. **SNAT Connection Count** - Outbound connection usage
4. **Byte Count** - Throughput metrics
5. **Packet Count** - Traffic volume

### View Metrics
```bash
# Using Azure CLI
az monitor metrics list \
  --resource <LOAD_BALANCER_RESOURCE_ID> \
  --metric "HealthProbeStatus" \
  --output table

# In Azure Portal
Resource → Metrics → Select metric
```

### Common Issues

#### 1. All Backends Unhealthy
- **Check**: Health probe configuration
- **Verify**: NSG allows health probe traffic (tag: AzureLoadBalancer)
- **Test**: Manually test endpoint (curl, telnet)

#### 2. SNAT Port Exhaustion
- **Symptoms**: Outbound connections fail
- **Solution**: Add outbound rules, use more frontend IPs
- **Monitor**: SNAT connection count metric

#### 3. Uneven Distribution
- **Check**: Distribution mode (5-tuple vs SourceIP)
- **Verify**: Long-lived connections keep going to same backend
- **Consider**: Connection draining, session persistence needs

#### 4. NAT Rules Not Working
- **Check**: NSG allows traffic on specific ports
- **Verify**: VM is in backend pool
- **Test**: Telnet to public IP and NAT port

## Best Practices

### 1. Use Standard SKU
- Zone redundancy
- Better SLA (99.99%)
- Enhanced security
- More features

### 2. Configure Proper Health Probes
- Use HTTP/HTTPS probes when possible (more accurate)
- Set appropriate interval (5-15 seconds typical)
- Use dedicated health endpoint
- Return 200 only when ready to serve traffic

### 3. Implement NSG Rules
```hcl
# Allow health probes
security_rule {
  source_address_prefix = "AzureLoadBalancer"
  # ... other settings
}
```

### 4. Plan for Outbound Connectivity
- Configure outbound rules explicitly
- Allocate sufficient frontend IPs for SNAT
- Monitor SNAT port usage
- Consider NAT Gateway for high-volume scenarios

### 5. Use Availability Zones
- Distribute VMs across zones
- Use zone-redundant public IP
- Improves resiliency

### 6. Enable Diagnostics
```hcl
resource "azurerm_monitor_diagnostic_setting" "lb_diag" {
  target_resource_id = azurerm_lb.web_lb.id
  
  metric {
    category = "AllMetrics"
  }
}
```

### 7. Implement Connection Draining
- Use health probes to gracefully remove backends
- Update backend to return non-200 before maintenance
- Wait for connections to drain

## Cost Optimization

### Pricing Components
1. **Rules**: Charged per rule
2. **Data Processed**: GB of data flowing through LB
3. **Standard vs Basic**: Standard SKU has hourly charge

### Tips to Reduce Costs
- Consolidate rules where possible
- Use Basic SKU for dev/test (but not production)
- Review unused rules
- Consider direct VM access for management (jumpbox)
- Use internal LB when public access not needed

## Integration Patterns

### With Application Gateway
```
Internet → App Gateway (SSL, WAF, routing) → Load Balancer → App Tier VMs
```

### With Azure Front Door
```
Global Users → Front Door → Regional Load Balancers → Backend VMs
```

### With Traffic Manager
```
DNS Query → Traffic Manager → Multiple Load Balancers (different regions)
```

### With NAT Gateway
```
Backend VMs → NAT Gateway → Internet (outbound)
Load Balancer → Backend VMs (inbound)
```

## Security Considerations

### 1. Network Security Groups
- Required for Standard LB (secure by default)
- Explicitly allow required traffic
- Use service tags (AzureLoadBalancer)

### 2. DDoS Protection
- Standard SKU includes basic DDoS protection
- Consider DDoS Protection Standard for critical workloads

### 3. Private Access
- Use internal Load Balancer for private apps
- No public IP exposure
- Access via VPN/ExpressRoute

### 4. SSL/TLS
- Load Balancer doesn't terminate SSL
- Use Application Gateway or VMSS with SSL
- Or handle SSL on backend VMs

## Migration from Basic to Standard

```bash
# 1. Note existing configuration
az network lb show --resource-group RG --name lb-basic

# 2. Create new Standard LB
# Use Terraform or Azure CLI

# 3. Update NSG rules
# Add AzureLoadBalancer service tag

# 4. Update backend VMs
# Associate with new LB

# 5. Update DNS/routing
# Point to new LB frontend IP

# 6. Verify traffic flow
# Test all endpoints

# 7. Remove old Basic LB
terraform destroy -target=azurerm_lb.old_basic_lb
```

## Next Steps

1. **Deploy the configuration**: Run `terraform apply`
2. **Test health probes**: Verify backends are healthy
3. **Test load distribution**: Make multiple requests
4. **Try NAT rules**: SSH to individual VMs
5. **Monitor metrics**: Check Azure Monitor
6. **Experiment**: Try different distribution modes
7. **Compare**: Access same VMs via Application Gateway and Load Balancer

## Useful Commands

```bash
# List all Load Balancers
az network lb list --output table

# Show LB details
az network lb show --resource-group RG --name LB_NAME

# List backend pool members
az network lb address-pool show \
  --resource-group RG \
  --lb-name LB_NAME \
  --name POOL_NAME

# Check probe status
az network lb probe show \
  --resource-group RG \
  --lb-name LB_NAME \
  --name PROBE_NAME

# List rules
az network lb rule list \
  --resource-group RG \
  --lb-name LB_NAME \
  --output table

# Test connection
curl -v http://<LB_PUBLIC_IP>
```

## Resources

- [Azure Load Balancer Documentation](https://docs.microsoft.com/azure/load-balancer/)
- [Choose the right load balancer](https://docs.microsoft.com/azure/architecture/guide/technology-choices/load-balancing-overview)
- [Load Balancer pricing](https://azure.microsoft.com/pricing/details/load-balancer/)
- [SKU comparison](https://docs.microsoft.com/azure/load-balancer/skus)
