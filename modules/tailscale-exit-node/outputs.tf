output "vm_id" {
  description = "Resource ID of the exit node VM."
  value       = azurerm_linux_virtual_machine.this.id
}

output "vm_name" {
  description = "Name of the exit node VM."
  value       = azurerm_linux_virtual_machine.this.name
}

output "private_ip_address" {
  description = "Private IPv4 address of the exit node."
  value       = azurerm_network_interface.this.private_ip_addresses[0]
}

output "public_ipv4_address" {
  description = "Public IPv4 address of the exit node, null if disabled."
  value       = var.enable_public_ipv4_address ? azurerm_public_ip.ipv4[0].ip_address : null
}

output "public_ipv6_address" {
  description = "Public IPv6 address of the exit node, null if disabled."
  value       = var.enable_public_ipv6_address ? azurerm_public_ip.ipv6[0].ip_address : null
}
