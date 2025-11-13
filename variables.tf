# Azure Authentication Variables
variable "azure_subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "Azure Tenant ID"
  type        = string
  sensitive   = true
}

variable "azure_client_id" {
  description = "Azure Service Principal Client ID"
  type        = string
  sensitive   = true
}

variable "azure_client_secret" {
  description = "Azure Service Principal Client Secret"
  type        = string
  sensitive   = true
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-appgw-lab"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "centralindia"
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "vnet-appgw-lab"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "appgw_subnet_name" {
  description = "Name of the Application Gateway subnet"
  type        = string
  default     = "subnet-appgw"
}

variable "appgw_subnet_prefix" {
  description = "Address prefix for Application Gateway subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "backend_subnet_name" {
  description = "Name of the backend VMs subnet"
  type        = string
  default     = "subnet-backend"
}

variable "backend_subnet_prefix" {
  description = "Address prefix for backend subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "appgw_pip_name" {
  description = "Name of the Application Gateway public IP"
  type        = string
  default     = "pip-appgw-lab"
}

variable "appgw_name" {
  description = "Name of the Application Gateway"
  type        = string
  default     = "appgw-lab-basic"
}

variable "appgw_sku_name" {
  description = "SKU name for Application Gateway (Standard_v2 or WAF_v2)"
  type        = string
  default     = "Standard_v2"
}

variable "appgw_sku_tier" {
  description = "SKU tier for Application Gateway (Standard_v2 or WAF_v2)"
  type        = string
  default     = "Standard_v2"
  
  validation {
    condition     = contains(["Standard_v2", "WAF_v2"], var.appgw_sku_tier)
    error_message = "SKU tier must be either Standard_v2 or WAF_v2"
  }
}

variable "appgw_capacity" {
  description = "Number of Application Gateway instances (1-125)"
  type        = number
  default     = 1
  
  validation {
    condition     = var.appgw_capacity >= 1 && var.appgw_capacity <= 125
    error_message = "Capacity must be between 1 and 125"
  }
}

variable "waf_mode" {
  description = "WAF mode: Detection or Prevention (only used if SKU is WAF_v2)"
  type        = string
  default     = "Detection"
  
  validation {
    condition     = contains(["Detection", "Prevention"], var.waf_mode)
    error_message = "WAF mode must be either Detection or Prevention"
  }
}

variable "vm_size" {
  description = "Size of the backend VMs"
  type        = string
  default     = "Standard_B2s"
}

variable "vm1_private_ip" {
  description = "Private IP address for VM1"
  type        = string
  default     = "10.0.2.4"
}

variable "vm2_private_ip" {
  description = "Private IP address for VM2"
  type        = string
  default     = "10.0.2.5"
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key for VM authentication"
  type        = string
  sensitive   = true
  
  # Generate with: ssh-keygen -t rsa -b 4096 -f ~/.ssh/appgw_lab_rsa
  # Then use: cat ~/.ssh/appgw_lab_rsa.pub
}

variable "ssl_certificate_data" {
  description = "Base64-encoded PFX certificate data for HTTPS"
  type        = string
  sensitive   = true
  
  # For lab: Use the appgw-cert.pfx file
  # Convert to base64: [Convert]::ToBase64String([IO.File]::ReadAllBytes("appgw-cert.pfx"))
}

variable "ssl_certificate_password" {
  description = "Password for the SSL certificate"
  type        = string
  sensitive   = true
  default     = ""
}

variable "enable_diagnostics" {
  description = "Enable diagnostic settings for Application Gateway"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
  default     = "law-appgw-lab"
}

variable "create_self_signed_cert" {
  description = "Create a self-signed certificate in Key Vault (for testing only)"
  type        = bool
  default     = false
}
