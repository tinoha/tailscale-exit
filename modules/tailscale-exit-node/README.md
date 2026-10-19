# tailscale-exit-node

Creates an ephemeral Tailscale exit node VM in Azure: NIC, optional public
IPv4/IPv6 addresses, an NSG that is always attached to the NIC and denies all
inbound traffic from the internet (with an opt-in SSH allow rule), the VM
itself, a daily auto-shutdown schedule (cost control) and a cloud-init
bootstrap that installs Tailscale and advertises the node as an exit node.

The module consumes an externally managed **anchor resource group** (by name)
and a `subnet_id` produced by the [`networking`](../networking) module. It
never manages the resource group itself or the virtual network.

## Usage

```hcl
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
  enable_auto_shutdown       = true
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9 |
| azurerm | >= 4.0 |

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| context | Deployment context used for resource naming | object({project, environment, location}) | n/a |
| rg_name | Name of the externally managed (anchor) resource group | string | n/a |
| subnet_id | Subnet resource ID for the NIC (from the networking module) | string | n/a |
| tailscale_auth_key | Tailscale auth key; use an ephemeral (reusable=false) key | string (sensitive) | n/a |
| admin_ssh_public_key | SSH public key (OpenSSH format) for the admin user; optional, only needed for plain OpenSSH (Tailscale SSH needs none) | string | "" |
| tags | Tags applied to all resources | map(string) | {} |
| admin_username | VM admin username | string | azureadmin |
| vm_size | Azure VM size (availability varies per region) | string | Standard_B1ls |
| vm_image | Marketplace image reference | object({publisher, offer, sku, version}) | Ubuntu 26.04 minimal |
| enable_public_ipv4_address | Create a public IPv4 address | bool | false |
| enable_public_ipv6_address | Create a public IPv6 address | bool | false |
| enable_ssh_access | Add an SSH allow rule (tcp/22 from anywhere) to the deny-by-default NSG attached to the NIC | bool | false |
| enable_auto_shutdown | Enable the daily auto-shutdown schedule | bool | false |
| auto_shutdown_time | Auto-shutdown time, 24-hour HH:mm | string | 21:00 |
| auto_shutdown_timezone | Auto-shutdown timezone (Windows name) | string | FLE Standard Time |

## Outputs

| Name | Description |
|------|-------------|
| vm_id | Resource ID of the exit node VM |
| vm_name | Name of the exit node VM |
| private_ip_address | Private IPv4 address of the exit node |
| public_ipv4_address | Public IPv4 address, null if disabled |
| public_ipv6_address | Public IPv6 address, null if disabled |

## Notes

- The NSG is always created and attached to the NIC. With no allow rules it
  denies all inbound traffic from the internet (Azure default rules); outbound
  is unaffected, which is what the exit node needs. The `enable_ssh_access`
  flag only adds a tcp/22 allow rule to this existing NSG.
- The auth key is injected into VM `custom_data` and is therefore visible in
  Terraform state. Use short-lived, ephemeral (reusable=false) keys.
- Tailscale SSH is enabled in cloud-init (`--ssh`), which covers SSH over the
  tailnet; internet-facing SSH (`enable_ssh_access`) is only needed for direct
  access.
- Applying this module to an existing deployment adds the NSG and its NIC
  association — additive only; the VM and NIC are not replaced.
