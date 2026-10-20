# Tailscale exit node on Azure

A personal Tailscale exit node running on an Azure VM. Deploy it in the region you want, use it when needed, then destroy it.

This is a small Terraform project to experiment with Azure, Tailscale and disposable infrastructure. It also demonstrates a fixed resource group as an RBAC boundary, region-specific resource naming, and modules organized by lifecycle.

**Not an anonymity tool.** Traffic exits through Azure using your own subscription. Your Azure account and the infrastructure you deploy may be traceable to you. A VPN changes your apparent public IP address; it does not make you anonymous.

## How it works

Your client connects to your Tailscale tailnet and uses the Azure VM as an exit node. Internet traffic routed through the exit node leaves from Azure rather than your local network.

```text
 ┌────────┐                        ┌────────────────────────────────────────────┐
 │ Client │─── Tailscale tailnet ─▶│           rg-tailscale-exit-node           │
 └────────┘                        ├────────────────────────────────────────────┤
                                   │ (anchor resource group, outside Terraform) │
                                   │                                            │
                                   │ Workload — managed by Terraform,           │
                                   │ in the region you choose:                  │
                                   │ ├─ VNet + subnet                           │
                                   │ ├─ VM + NIC (the exit node)                │
                                   │ ├─ Public IPv4 + IPv6                      │
                                   │ ├─ NSG (deny-all inbound)                  │
                                   │ └─ Daily auto-shutdown                     │
                                   └──────────────────────┬─────────────────────┘
                                                          │ egress
                                                          ▼
                                                       Internet
```

The anchor resource group is created manually; the examples use `swedencentral` for it and `japaneast` for the workload. These regions are independent and can be different.

## Requirements

- An Azure subscription with permission to deploy the required resources.
- [Terraform](https://developer.hashicorp.com/terraform/install) compatible with the version constraints in this repository.
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli).
- A [Tailscale](https://tailscale.com/) account and an auth key configured for ephemeral, single-use registration.
- An SSH public key if you want direct OpenSSH access to the VM.

## Quickstart

### 1. Log in to Azure

```bash
az login
az account set --subscription "<name-or-id>"
```

Make sure you have selected the subscription where you want to deploy the resources.

### 2. Create the anchor resource group

Create the resource group once. Terraform references it but does not create or delete it.

```bash
az group create \
  --name rg-tailscale-exit-node \
  --location swedencentral
```

The resource group's region does not determine the workload region.

### 3. Create a Tailscale auth key

In the Tailscale admin console, create an auth key with these recommended settings:
- **Ephemeral**: enabled. The node is automatically removed from the tailnet after it goes offline and is detected as ephemeral and inactive. This avoids leaving stale machine entries after terraform destroy.
- **Reusable**: disabled. The key can register only one node.
- **Expiration**: a short validity period, such as one day. Expiration determines how long the key can be used to register a device, not how long an already-registered node remains in the tailnet.

These are recommended defaults, not requirements imposed by the Terraform configuration. Choose the key validity period and reuse settings according to your needs.

The auth key is passed to the VM through cloud-init. Assume that it remains accessible within the VM's provisioning data and may be present in Terraform state. Protect both accordingly.

### 4. Configure the deployment

Clone the repository and create your local configuration file:

```bash
cd environments/prod
cp terraform.tfvars.example terraform.tfvars
```

Set the target region (`location`) and Tailscale auth key in `terraform.tfvars`:

```hcl
location           = "japaneast"
tailscale_auth_key = "tskey-auth-..."
```

The other variables have defaults. See [`environments/prod/README.md`](environments/prod/README.md) for the complete variable reference.

Alternatively, you may supply the auth key as an environment variable:

```bash
export TF_VAR_tailscale_auth_key="tskey-auth-..."
```

If you want direct OpenSSH access, set `admin_ssh_public_key` as described in the variable reference. OpenSSH access from the internet additionally requires setting `enable_ssh_access = true` in `environments/prod/main.tf`; the NSG denies all inbound traffic until then. Only provide your public key, never your private key.

Treat the auth key and Terraform state as sensitive data.

### 5. Deploy

From `environments/prod`, run:

```bash
terraform init
terraform plan
terraform apply
```

Review the plan before applying it.

Terraform creates the workload in the configured region. The outputs include the VM details and its private IPv4, public IPv4 and public IPv6 addresses.

Allow time for the VM to initialize and register with Tailscale.

### 6. Approve and select the exit node

In the [Tailscale admin console](https://login.tailscale.com/admin/machines), locate the new machine and approve it for exit-node use if required.

On a client, select the new exit node:

```bash
tailscale set --exit-node=<node-name>
```

Replace `<node-name>` with the machine's Tailscale name. You can also select the exit node in the Tailscale client application.

Verify that traffic exits through Azure:

```bash
curl https://ifconfig.me
```

The reported public IP should correspond to the Azure VM's outbound internet address.

To stop using the exit node, deselect it in your Tailscale client.

## Configuration

The project provides defaults for the main deployment settings, so only a few variables are normally needed.

| Setting | Default or behavior |
|---|---|
| Anchor resource group | `rg-tailscale-exit-node`, created manually |
| Anchor resource group region | `swedencentral` in the example |
| Azure region (`location`) | `swedencentral`; the example configuration uses `japaneast` |
| VM size | `Standard_B1ls` |
| OS disk | `Standard_LRS` |
| Auto-shutdown | Daily at 21:00 |
| Shutdown timezone | `FLE Standard Time` |
| Inbound internet access | Denied by default |
| Password-based SSH | Disabled |
| SSH access (NSG rule) | Disabled unless explicitly enabled |

See [`environments/prod/README.md`](environments/prod/README.md) for all variables and their defaults.

VM sizes and other Azure resources may not be available in every region. Select a compatible VM size when deploying to a region that does not support the default.

## Moving to another region

Changing `location` changes the names of the workload resources and requires a replacement deployment. The intended relocation process is to destroy the current workload and deploy it again.

From `environments/prod`:

```bash
terraform destroy
```

Change `location` in `terraform.tfvars`, for example:

```hcl
location = "swedencentral"
```

Then deploy again:

```bash
terraform plan
terraform apply
```

The anchor resource group remains untouched. The new VM registers as a new machine. Approve it for exit-node use if required, then select it on your client.

Check VM size availability in the target region before applying.

The auto-shutdown schedule uses a Windows timezone name. Its configured timezone is independent of the Azure region.

## Cleanup

From `environments/prod`, destroy the workload:

```bash
terraform destroy
```

This removes the VM and its OS disk, the NIC, the public IPs, the NSG, the shutdown schedule and the VNet with its subnet. The anchor resource group and anything else in it remain. If you are done for good, delete the group separately:

```bash
az group delete --name rg-tailscale-exit-node
```

## Security and limitations
- **Not an anonymity tool.** Traffic exits through Azure using your own subscription. Microsoft can associate the deployed infrastructure with your Azure account and may be able to correlate network activity with the VM and its public IP addresses. A VPN changes your apparent public IP address; it does not make you anonymous.
- **Inbound access is denied by default.** The VM NIC has an NSG with no custom inbound internet allow rules. Tailscale SSH is the intended access method. Password-based SSH authentication is disabled. Providing an SSH public key and setting `enable_ssh_access = true` enables key-based OpenSSH access from the internet.
- **Protect the VM and Terraform state.** The Tailscale auth key is injected through cloud-init and may remain in the VM's provisioning data and Terraform state. Use an ephemeral, single-use key with a short validity period. Password-based SSH authentication is disabled, and inbound internet access is denied by default. A compromised VM may expose active Tailscale credentials, allow an attacker to use the node's tailnet access, and expose traffic passing through the exit node.
- **Tailnet policy is your responsibility.** This project does not configure custom Tailscale grants or ACLs. Access depends on your existing tailnet policy; review it according to your requirements.
- **Destroy when finished.** Auto-shutdown reduces the chance of leaving the VM running, but disks and other resources may still incur charges. See [Cleanup](#cleanup) for the teardown steps.

## Repository layout

```text
.
├── environments/
│   └── prod/                       # Deployable root module
│       ├── main.tf                 # Anchor lookup and module configuration
│       ├── variables.tf            # Deployment variables
│       ├── outputs.tf              # VM details and addresses
│       ├── terraform.tfvars.example
│       ├── backend.tf              # Local state
│       ├── providers.tf            # AzureRM provider configuration
│       └── versions.tf             # Terraform and provider constraints
└── modules/
    ├── networking/                 # VNet and subnet
    └── tailscale-exit-node/        # VM, IPs, NIC, NSG and shutdown
```

## Design decisions

- **Fixed deployment boundary.** The anchor resource group is created outside Terraform and referenced as a data source. Terraform manages the workload inside it without owning the group itself.
- **Region-specific naming.** Resource names include the deployment context and region. Changing the region replaces the workload rather than attempting an in-place migration.
- **Modules organized by lifecycle.** Networking is separated from VM-bound resources so that network ownership and workload replacement remain distinct.
- **Low-cost defaults.** A small VM, standard OS disk and automatic shutdown schedule reduce the cost of experimenting with the deployment.

## License

[MIT](LICENSE) — built by [tinoha](https://github.com/tinoha).
