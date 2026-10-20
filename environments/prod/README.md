# Tailscale exit node (prod)

Deployable Terraform root module for the exit node. See the
[root README](../../README.md) for the full walkthrough, design decisions and
security notes.

## Deploy

Run from this directory:

```bash
cp terraform.tfvars.example terraform.tfvars   # set location + tailscale_auth_key
terraform init
terraform plan
terraform apply
```

`terraform destroy` removes the workload; the anchor resource group remains.

## Variables

All variables have defaults except `tailscale_auth_key`, which is required.

| Variable | Description | Default |
|---|---|---|
| `location` | Azure region for the workload. Flipping it recreates the resources; names embed the region. | `swedencentral` |
| `rg_name` | Name of the pre-created anchor resource group. Not managed by Terraform. | `rg-tailscale-exit-node` |
| `project` | Project name used in resource names and tags. | `tailscale` |
| `environment` | Environment name used in resource names and tags. | `prod` |
| `custom_tags` | Extra tags merged over the default tags (`environment`, `project`, `managed-by`). | `{}` |
| `tailscale_auth_key` | Tailscale auth key for the exit node. Supply via `TF_VAR_tailscale_auth_key`. An ephemeral (`reusable=false`) key is recommended. | — |
| `admin_ssh_public_key` | SSH public key for the admin user. Optional; only needed for OpenSSH. | `""` |
| `vm_size` | Azure VM size. Not available in every region. | `Standard_B1ls` |

## Notes

- Internet-facing SSH: set `enable_ssh_access = true` in `main.tf` (not a
  variable). The NSG denies all inbound traffic until then.
- State is local (`backend.tf`) and contains the auth key. Treat it as
  sensitive.
