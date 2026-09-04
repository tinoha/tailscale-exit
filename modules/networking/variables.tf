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

variable "tags" {
  description = "Map of tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "vnet_address_space" {
  description = "Address spaces (CIDRs) assigned to the virtual network. Supports both IPv4 and IPv6."
  type        = list(string)
  default     = ["10.90.0.0/16", "fd41:cbfa:feba::/48"]
}

variable "subnet_address_prefixes" {
  description = "Address prefixes (CIDRs) assigned to the subnet. Supports both IPv4 and IPv6."
  type        = list(string)
  default     = ["10.90.1.0/24", "fd41:cbfa:feba:1::/64"]
}
