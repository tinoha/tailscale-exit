# Tailscale exit node on Azure

An ephemeral, private Tailscale exit node running on Azure. Spin it up when you
need your traffic to leave from another region, use it, then destroy it.
Relocating the node to another region is a one-variable change — the whole
footprint is recreated, so it is a destroy-and-redeploy by design.

This is a small Terraform project built to demonstrate a few things I care
about: a fixed **anchor resource group** as an RBAC boundary, resource names
that embed their deployment context, and a clean split between networking and
workload. It is also a bit of fun — everyone should have their own VPN.

> **Not an anonymity tool.** Traffic exits through Azure under your own
> subscription and account. Tailscale (and Azure) can see the same things your
> normal cloud provider would.

## How it works

```
                        Tailscale tailnet
  ┌──────────────┐            │            ┌──────────────────────────────┐
  │ Laptop       │────────────┤            │ Azure subscription           │
  │ (exit-node   │            │            │                              │
  │  client)     │            └───────────▶│  Anchor RG (fixed region)    │
  └──────────────┘                         │  └─ VNet + subnet            │
                                           │     └─ Exit node VM          │
                                           │        (selected region)     │
                                           └──────────────────────────────┘
```

The VM advertises itself as an exit node via cloud-init:

```bash
tailscale up --authkey=... --advertise-exit-node --ssh
```

Approve the route in the Tailscale admin console, select the node on a client,
and your traffic egresses from the VM's Azure region.

## Design decisions

**The anchor resource group is not managed by Terraform.** It is created
out-of-band and referenced with a `data` lookup. Terraform deploys *into* it but
never creates or destroys it. This gives you a stable RBAC boundary: the
identity running the configuration only needs rights inside that one group, and
`terraform destroy` can never remove the group itself. The group's own region is
irrelevant — every resource is placed in `var.location`, which may differ.

**The region is part of every resource name.** Names follow
`<type>-<project>-<environment>-<location>`, for example
`vm-tailscale-prod-japaneast`. Because the region is embedded in the names,
changing `var.location` replaces the network, IPs, NIC and VM. The documented
path for relocating is a clean `terraform destroy` → change → `terraform apply`.
The anchor resource group stays untouched.

**Modules are split by lifecycle, not by resource type.** `networking` owns
addressing only (VNet and subnet). VM-bound resources — public IPs, NIC, NSG and
the shutdown schedule — live in `tailscale-exit-node` next to the VM they are
replaced with. The shared network is never coupled to one workload.

**Cost is kept deliberately low.** The default size is `Standard_B1ls`, the OS
disk is `Standard_LRS`, and a daily auto-shutdown schedule stops the VM at
21:00 local time (configurable, `FLE Standard Time` by default). Auto-shutdown
is a safety net for a forgotten node; it is not a substitute for
`terraform destroy`.

**Secure by default.** The VM's NIC always carries an NSG that denies all
inbound traffic from the internet — nothing is reachable unless you opt in.
SSH over the tailnet uses Tailscale SSH: authentication is your tailnet
identity (with a periodic browser check prompt), not an SSH key — it works
without providing one. The `admin_ssh_public_key` is optional and only needed
for plain OpenSSH (which additionally requires `enable_ssh_access = true`,
adding a tcp/22 allow rule to the otherwise empty NSG). The auth key is an
ephemeral, single-use key; it is injected into the VM's `custom_data` and is
therefore visible in Terraform state — use short-lived keys.

## Repository layout

```
.
├── environments/
│   └── prod/                     # deployable root module
│       ├── main.tf               # anchor lookup, modules, feature flags
│       ├── variables.tf          # location, naming, secrets, VM size
│       ├── outputs.tf            # VM name/ID and addresses
│       ├── terraform.tfvars.example # variable template; copy to terraform.tfvars
│       ├── backend.tf            # local state
│       ├── providers.tf          # azurerm + resource provider registration
│       └── versions.tf           # Terraform and provider constraints
└── modules/
    ├── networking/               # VNet + subnet (addressing only)
    └── tailscale-exit-node/      # VM, IPs, NIC, NSG, shutdown, cloud-init
```

## Requirements

| Tool      | Version   |
|-----------|-----------|
| Terraform | `~> 1.16` |
| azurerm   | `~> 5.3`  |
| Azure CLI | current   |

You also need an Azure subscription, a Tailscale account and a Tailscale auth
key (ephemeral, `reusable=false`, recommended). An SSH public key is optional —
only needed if you want plain OpenSSH to the VM.

## Quickstart

1. Log in and select the subscription:

   ```bash
   az login
   az account set --subscription "<name-or-id>"
   ```

2. Create the anchor resource group once. Terraform deploys into it but does not
   manage it, so its region does not need to match the exit node's:

   ```bash
   az group create --name rg-tailscale-exit-node --location swedencentral
   ```

3. Create your `terraform.tfvars` from the committed example — the real file
   is gitignored and stays local:

   ```bash
   cd environments/prod
   cp terraform.tfvars.example terraform.tfvars
   ```

   ```hcl
   location           = "japaneast"
   tailscale_auth_key = "tskey-auth-..."   # ephemeral (reusable=false)
   ```

   Everything else has a default; see [`environments/prod/README.md`](environments/prod/README.md)
   for the full variable list. Alternatively, keep secrets out of files and
   supply them via environment variables instead:

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

5. In the Tailscale admin console, approve the new machine as an exit node
   (Machines → your node → Edit exit node → Use as exit node).

6. On a client, select the exit node:

   ```bash
   tailscale set --exit-node=<node-name>
   ```

   Or connect to the VM over the tailnet (Tailscale SSH may ask for a browser
   check):

   ```bash
   ssh azureadmin@<node-name>
   ```

## Moving the node to another region

Changing `location` replaces every workload resource, so destroy first and
re-apply cleanly:

```bash
cd environments/prod

terraform destroy

# edit terraform.tfvars: location = "japaneast"

terraform apply
```

The anchor resource group is left untouched. After applying, approve the new
node as an exit node in the admin console — it is a new machine to Tailscale.

Two things to check when relocating:

- **VM size availability** — `Standard_B1ls` is not offered in every region.
  Set `vm_size` to a size that exists in the target region.
- **Auto-shutdown timezone** — the schedule uses a Windows timezone name
  (`FLE Standard Time` by default), independent of the Azure region.

## Cleanup

```bash
cd environments/prod
terraform destroy
```

This removes the VM, disks, network, public IPs and the shutdown schedule. The
anchor resource group and anything else in it remain. If you are done for good,
delete the group separately:

```bash
az group delete --name rg-tailscale-exit-node
```

## Notes and limitations

- **The auth key is in Terraform state.** It is embedded in the VM's
  `custom_data`. Use a short-lived ephemeral key and treat the state file as a
  secret. State is local (`backend.tf`), so this setup assumes a single
  operator.
- **The exit node is a fresh machine after relocation.** Its name and public IPs
  change; the old entry should be removed from the tailnet (ephemeral keys do
  this automatically).
- **Internet inbound is denied by the NSG.** Tailscale SSH over the tailnet is
  the intended path. If a direct WireGuard path cannot open (inbound UDP is
  blocked too), Tailscale relays via DERP automatically. Set
  `enable_ssh_access = true` only if you need internet-facing SSH; it adds a
  tcp/22 allow rule to the otherwise empty NSG.
- **Exit nodes are trusted infrastructure.** A compromised exit node can
  observe the traffic passing through it — inherent to using any exit node.
  On tailnets with several devices, tailnet policy can further isolate the
  node; see Tailscale's security documentation.
- **Not an anonymity service.** See the note at the top.

## License

[MIT](LICENSE) — built by [tinoha](https://github.com/tinoha).
