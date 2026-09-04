locals {
  # Name prefix for resources, based on the deployment context:
  # <project>-<environment>-<location>
  name_prefix = join("-", compact([
    var.context.project,
    var.context.environment,
    var.context.location
  ]))

  # Cloud-init user data, with the Tailscale auth key injected.
  cloud_init = templatefile("${path.module}/cloud-init", {
    tailscale_auth_key = var.tailscale_auth_key
  })
}
