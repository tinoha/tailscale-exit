# Tailscale exit node (prod)

An ephemeral Tailscale exit node on Azure — handy when you want your traffic
to leave from another country, for example Japan. It runs on a small VM, shuts
down nightly, and can be destroyed when you no longer need it.

> **Not an anonymity tool.** Traffic exits through Azure under your own
> subscription and account.

## Prerequisites

- An Azure subscription and a Tailscale account
- Azure CLI (`az`) and Terraform ~> 1.16
- A Tailscale auth key (ephemeral recommended)
- An SSH public key (optional — only for plain OpenSSH)

## Deploy

1. Log in and select your subscription:

   ```bash
   az login
   az account set --subscription "<name-or-id>"
   ```

2. Create the anchor resource group. Terraform deploys into it but does not
   manage it, so its region does not need to match the VM's:

   ```bash
   az group create --name rg-tailscale-exit-node --location swedencentral
   ```

3. Create `terraform.tfvars` (gitignored) from the committed example:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

   Fill in `location` (for example `japaneast`) and your secrets. Override
   `rg_name` if you used a different resource group name. `vm_size` defaults
   to `Standard_B1ls`, which is not available in every region.

   Secrets can instead be supplied via environment variables, so they never
   touch a file — the SSH key is optional (only for plain OpenSSH):

   ```bash
   export TF_VAR_tailscale_auth_key="tskey-auth-..."
   export TF_VAR_admin_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"   # optional
   ```

4. Apply:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Use

1. In the Tailscale admin console, approve the new machine as an exit node
   (Machines → your node → Edit exit node → Use as exit node).
2. On a client, select it in the Tailscale app or run:

   ```bash
   tailscale set --exit-node=<node-name>
   ```

3. Connect over the tailnet if needed:

   ```bash
   ssh azureadmin@<node-name>
   ```

## Costs and cleanup

- The VM shuts down daily at 21:00 in `auto_shutdown_timezone`
- `terraform destroy` removes the VM, network and disks. Only the anchor resource
  group is left untouched.

## Notes

- The auth key is embedded in the VM's `custom_data` and is therefore visible
  in Terraform state. Use a short-lived ephemeral key.
- The VM's NIC carries an NSG that denies all inbound traffic from the
  internet. SSH over the tailnet uses Tailscale SSH; internet-facing SSH is
  opt-in via `enable_ssh_access = true` in `main.tf`.
- State is local (`backend.tf`), so this setup assumes a single operator.

## Layout

- [`../../modules/networking`](../../modules/networking) — VNet and subnet
- [`../../modules/tailscale-exit-node`](../../modules/tailscale-exit-node) — VM, networking, auto-shutdown, Tailscale bootstrap
