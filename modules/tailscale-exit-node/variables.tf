variable "context" {
  description = "Deployment context used for resource naming: <project>-<environment>-<location>."
  type = object({
    project     = string
    environment = string
    location    = string
  })
}

variable "rg_name" {
  description = "Name of the (externally managed, anchor) resource group resources are created in."
  type        = string
}

variable "subnet_id" {
  description = "Resource ID of the subnet the exit node NIC is attached to (from the networking module)."
  type        = string
}

variable "tags" {
  description = "Map of tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "tailscale_auth_key" {
  description = "Tailscale auth key used to authenticate the node to the tailnet. Use an ephemeral (reusable=false) key; it is embedded in VM custom_data and therefore visible in state."
  type        = string
  sensitive   = true
}

variable "admin_username" {
  description = "Admin username for the VM."
  type        = string
  default     = "azureadmin"
}

variable "admin_ssh_public_key" {
  description = "SSH public key (OpenSSH format) authorized for the VM admin user."
  type = string
}

variable "vm_size" {
  description = "Azure VM size. Not all sizes exist in all regions; adjust when deploying outside the default region."
  type        = string
  default     = "Standard_B1ls"
}

variable "vm_image" {
  description = "Marketplace image reference for the VM."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "Canonical"
    offer     = "ubuntu-26_04-lts"
    sku       = "minimal"
    version   = "latest"
  }
}

variable "enable_public_ipv4_address" {
  description = "Create a public IPv4 address for the exit node."
  type        = bool
  default     = false
}

variable "enable_public_ipv6_address" {
  description = "Create a public IPv6 address for the exit node."
  type        = bool
  default     = false
}

variable "enable_ssh_access" {
  description = "Create an NSG allowing inbound public SSH to the VM. Note: Tailscale SSH (--ssh in cloud-init) already covers SSH over the tailnet without this."
  type        = bool
  default     = false
}

variable "enable_auto_shutdown" {
  description = "Enable the daily auto-shutdown schedule for the VM (cost control for the ephemeral node)."
  type        = bool
  default     = false
}

variable "auto_shutdown_time" {
  description = "Daily auto-shutdown time in 24-hour HH:mm format."
  type        = string
  default     = "21:00"

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.auto_shutdown_time))
    error_message = "auto_shutdown_time must be in 24-hour HH:mm format, e.g. \"21:00\"."
  }
}

variable "auto_shutdown_timezone" {
  description = "Timezone id for the auto-shutdown schedule (Windows timezone name)."
  type        = string
  default     = "FLE Standard Time"
}
