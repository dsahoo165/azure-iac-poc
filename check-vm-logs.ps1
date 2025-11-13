# Script to check web server logs on VMs via Load Balancer NAT rules

Write-Host "=== Checking VM1 Access Logs ===" -ForegroundColor Cyan
Write-Host "SSH Command: ssh -p 2201 azureuser@74.225.147.64" -ForegroundColor Yellow
Write-Host "Once connected, run: sudo tail -20 /var/log/nginx/access.log"
Write-Host ""

Write-Host "=== Checking VM2 Access Logs ===" -ForegroundColor Cyan
Write-Host "SSH Command: ssh -p 2202 azureuser@74.225.147.64" -ForegroundColor Yellow
Write-Host "Once connected, run: sudo tail -20 /var/log/nginx/access.log"
Write-Host ""

Write-Host "=== OR Use Azure CLI to Run Remote Commands ===" -ForegroundColor Cyan
Write-Host ""

# VM1 logs
Write-Host "Getting VM1 logs..." -ForegroundColor Green
az vm run-command invoke `
  --resource-group rg-appgw-lab `
  --name vm-web1 `
  --command-id RunShellScript `
  --scripts "tail -20 /var/log/nginx/access.log" `
  --query 'value[0].message' `
  --output tsv

Write-Host ""
Write-Host "Getting VM2 logs..." -ForegroundColor Green
az vm run-command invoke `
  --resource-group rg-appgw-lab `
  --name vm-web2 `
  --command-id RunShellScript `
  --scripts "tail -20 /var/log/nginx/access.log" `
  --query 'value[0].message' `
  --output tsv
