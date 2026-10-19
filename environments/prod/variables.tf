variable "location" {
  description = "Azure region where the resources are created. May differ from the anchor resource group's region. Flipping it recreates everything (names embed the region)."
  type        = string
  default     = "swedencentral"
}

variable "rg_name" {
  description = "Name of the pre-created anchor resource group. Not managed by Terraform."
  type        = string
  default     = "rg-tailscale-exit-node"
}

variable "project" {
  description = "Project name used in resource names and tagging."
  type        = string
  default     = "tailscale"
}

variable "environment" {
  description = "Environment name used in resource names and tagging."
  type        = string
  default     = "prod"
}

variable "custom_tags" {
  description = "Custom tags merged over the default tags (environment, project, managed-by)."
  type        = map(string)
  default     = {}
}

variable "tailscale_auth_key" {
  description = "Tailscale auth key used to authenticate the exit node. Supply via TF_VAR_tailscale_auth_key; an ephemeral (reusable=false) key is recommended."
  type        = string
  sensitive   = true
}

variable "admin_ssh_public_key" {
  description = "SSH public key (OpenSSH format) authorized on the exit node VM. Optional: Tailscale SSH works without it; only needed for OpenSSH. Supply via TF_VAR_admin_ssh_public_key."
  type        = string
  default     = ""
}

variable "vm_size" {
  description = "Azure VM size. Not available in every region; adjust when deploying elsewhere."
  type        = string
  default     = "Standard_B1ls"
}
