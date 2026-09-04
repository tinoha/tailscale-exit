# networking

Creates a virtual network and a subnet in an **externally managed (anchor)
resource group**. The module is deliberately workload-agnostic: it owns
addressing only. Firewall rules and VM-bound resources live with the modules
that consume the subnet (see `../tailscale-exit-node`).

Resource names are derived from the deployment context:
`vnet-<project>-<environment>-<location>`, `snet-<...>`. The location may
differ from the resource group's region.

## Usage

```hcl
module "networking" {
  source = "../../modules/networking"

  context = {
    project     = "tailscale"
    environment = "prod"
    location    = "swedencentral"
  }
  rg_name = "rg-tailscale-exit-node"
  tags    = local.merged_tags
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
| rg_name | Name of the externally managed resource group | string | n/a |
| tags | Tags applied to all resources | map(string) | {} |
| vnet_address_space | CIDRs for the virtual network (IPv4 and/or IPv6) | list(string) | ["10.90.0.0/16", "fd41:cbfa:feba::/48"] |
| subnet_address_prefixes | CIDRs for the subnet (IPv4 and/or IPv6) | list(string) | ["10.90.1.0/24", "fd41:cbfa:feba:1::/64"] |

## Outputs

| Name | Description |
|------|-------------|
| vnet_id | Resource ID of the virtual network |
| subnet_id | Resource ID of the subnet |
| subnet_address_prefixes | Address prefixes of the subnet, as assigned by Azure |
