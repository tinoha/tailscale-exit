# prod — Tailscale exit node

Ephemeral Tailscale exit node VM in Azure, kept cheap via daily auto-shutdown
and torn down with `terraform destroy` when not in use.

## Layout

- [`../../modules/networking`](../../modules/networking) — virtual network + subnet (addressing only, reusable)
- [`../../modules/tailscale-exit-node`](../../modules/tailscale-exit-node) — VM, NIC, public IPs, NSG, auto-shutdown, Tailscale bootstrap

State is local (`backend.tf`) — a deliberate single-user choice. No parallel
applies are expected.

## The anchor resource group

`rg_name` points to a **pre-created resource group that Terraform never
manages**. It exists as a static RBAC boundary: the Entra identity running
`terraform apply` needs rights only inside it, while resources can be deployed
into any `location` — the resource group's own region is irrelevant.

## Usage

Prerequisites: Terraform ~> 1.16, Azure CLI logged in (`az login`) with rights
on the anchor resource group.

Required input variables are supplied via environment variables (never
committed):

```sh
export TF_VAR_tailscale_auth_key="tskey-auth-..." # ephemeral (reusable=false) key recommended
export TF_VAR_admin_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"

terraform init
terraform plan
terraform apply
```

## Notes

- **Deploying to another region**: flip `location`. Everything is recreated —
  expected, since names embed the region. Check that `vm_size` (default
  `Standard_B1ls`) exists in the target region and that the subscription has
  quota there.
- **SSH**: Tailscale SSH is enabled in cloud-init and covers access over the
  tailnet. Public SSH (`enable_ssh_access = true` here) is a convenience; if
  kept, narrow `ssh_allowed_source_prefixes` (defaults to the whole internet).
- **Auth key**: injected into VM `custom_data`, therefore visible in state.
  Use short-lived ephemeral keys to limit blast radius.
- The auto-shutdown schedule fires at `auto_shutdown_time` (21:00 default).
