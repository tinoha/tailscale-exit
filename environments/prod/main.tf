# main.tf

# Resource naming used:
# <type>-<project>-<environment>-<region>[-<qualifier>]

### Anchor resource group ###

# The resource group is intentionally NOT managed by Terraform. It is created
# out-of-band and acts as a static RBAC boundary: the Entra identity running
# this configuration only needs rights within it. The resource group's own
# region is irrelevant; resources are placed in var.location, which may
# differ. This data lookup asserts the anchor exists and resolves its name.
data "azurerm_resource_group" "anchor" {
  name = var.rg_name
}

### Locals ###

locals {
  context = {
    project     = var.project
    environment = var.environment
    location    = var.location
  }

  # Merge custom tags from variable with default tags below. On overlapping
  # keys, values from var.custom_tags take precedence.
  merged_tags = merge(
    {
      environment = var.environment
      project     = var.project
      managed-by  = "terraform"
    },
    var.custom_tags
  )
}

### Modules ###

module "networking" {
  source = "../../modules/networking"

  context = local.context
  rg_name = data.azurerm_resource_group.anchor.name
  tags    = local.merged_tags
}

module "tailscale-exit-node" {
  source = "../../modules/tailscale-exit-node"

  context   = local.context
  rg_name   = data.azurerm_resource_group.anchor.name
  subnet_id = module.networking.subnet_id
  tags      = local.merged_tags

  tailscale_auth_key         = var.tailscale_auth_key
  admin_ssh_public_key       = var.admin_ssh_public_key
  enable_public_ipv4_address = true
  enable_public_ipv6_address = true
  enable_ssh_access          = false
  enable_auto_shutdown       = true
  auto_shutdown_time         = "21:00"

  vm_size = var.vm_size
}
