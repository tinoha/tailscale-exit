output "exit_node_vm_name" {
  description = "Name of the Tailscale exit node VM."
  value       = module.tailscale-exit-node.vm_name
}

output "exit_node_vm_id" {
  description = "Resource ID of the Tailscale exit node VM."
  value       = module.tailscale-exit-node.vm_id
}

output "exit_node_private_ipv4" {
  description = "Private IPv4 address of the Tailscale exit node."
  value       = module.tailscale-exit-node.private_ip_address
}

output "exit_node_public_ipv4" {
  description = "Public IPv4 address of the Tailscale exit node, null if disabled."
  value       = module.tailscale-exit-node.public_ipv4_address
}

output "exit_node_public_ipv6" {
  description = "Public IPv6 address of the Tailscale exit node, null if disabled."
  value       = module.tailscale-exit-node.public_ipv6_address
}
