# VM Scale Set (VMSS) ARM Template

This repository contains an ARM template to deploy a Linux Virtual Machine Scale Set (VMSS) into an existing subnet.

Files
- template.json — ARM template defining the VMSS.
- parameters.json — Example parameter values (replace placeholders like subscriptionId, rgName, vnetName, subnetName).
- deploy.ps1 — PowerShell script using `az` CLI to validate and deploy.

Quick deploy (Azure CLI)

1. Update `parameters.json` with your `subnetId` and `sshKeyData` and optionally `targetLocation` (default `southindia`).

2. Validate the template:

```bash
az deployment group validate --resource-group <your-rg> --template-file template.json --parameters @parameters.json --parameters targetLocation=<region>
```

3. Deploy:

```bash
az deployment group create --resource-group <your-rg> --template-file template.json --parameters @parameters.json --parameters targetLocation=<region>
```

Quick scripts
- PowerShell (will create the RG if missing):

```powershell
./deploy.ps1 -resourceGroupName <your-rg> -location southindia
```

- Bash:

```bash
nchmod +x deploy.sh
./deploy.sh <your-rg> southindia
```

Notes & region costs
- This template deploys Linux VMs and requires an SSH public key. Ensure the matching **private key** (not included here) is available locally to SSH into instances.
- Default `targetLocation` is `southindia` which is typically low-cost; costs vary by region and VM size. To find available low-cost sizes in the region run:

```powershell
Get-AzComputeResourceSku | Where-Object {$_.Locations -contains "southindia" -and $_.ResourceType -eq "virtualMachines"} | Select-Object -ExpandProperty Name | Sort-Object -Unique | Select-Object -First 40
```

- If a requested VM size is unavailable in the chosen region, change `vmSize` in `parameters.json` to another available SKU for that region.

Network Security Group (SSH/HTTP)
- The template now creates a Network Security Group named by `nsgName` and adds inbound rules to allow **TCP port 22 (SSH)** and **TCP port 80 (HTTP)** when `createVnet=true` (the NSG is attached to the subnet the template creates).
- If you deploy into an existing subnet (set `createVnet=false`), attach an NSG manually or pass an existing NSG by updating the subnet; I can add an optional parameter to update an existing subnet automatically if you want.

Load Balancer & nginx
- The template now creates a Load Balancer (named by `lbName`) with a public IP (`lbPublicIpName`) and a backend pool that automatically includes VMSS instances. The public IP is exposed via the `loadBalancerIp` output.
- The VMSS includes a Custom Script Extension that installs **nginx** on each instance at provisioning and writes an `index.html` showing the VM hostname and private IP address.
- The template now creates a Log Analytics Workspace (`lawName`) and installs the **OmsAgentForLinux** extension on the VMSS so VM Insights (per-instance CPU and other guest metrics) can be collected.
- The template can also create an **Autoscale setting** (CPU based) — defaults: **min=1, default=1, max=3**, scale-out when Average Percentage CPU > 20 (increase by 1), scale-in when Average Percentage CPU < 20 (decrease by 1). You can change these by editing parameters: `autoscaleMin`, `autoscaleDefault`, `autoscaleMax`, `autoscaleCpuScaleOutThreshold`, `autoscaleCpuScaleInThreshold`.
- Future scale-outs will automatically run the extensions so new instances will have nginx installed and be monitored as well.


Validation & deploy

- Validate the template using Azure CLI before deploying:

```bash
az deployment group validate --resource-group <your-rg> --template-file template.json --parameters @parameters.json
```

- Deploy using Azure CLI:

```bash
az deployment group create --resource-group <your-rg> --template-file template.json --parameters @parameters.json
```

- PowerShell (Windows/macOS with PowerShell):

```powershell
./deploy.ps1 -resourceGroupName <your-rg>
```

- Bash (Linux/macOS/WSL/Cygwin):

```bash
chmod +x deploy.sh
./deploy.sh <your-rg>
```
