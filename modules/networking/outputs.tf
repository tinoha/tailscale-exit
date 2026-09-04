output "vnet_id" {
  description = "Resource ID of the virtual network."
  value       = azurerm_virtual_network.this.id
}

output "subnet_id" {
  description = "Resource ID of the subnet."
  value       = azurerm_subnet.this.id
}

output "subnet_address_prefixes" {
  description = "Address prefixes of the subnet, as assigned by Azure."
  value       = azurerm_subnet.this.address_prefixes
}
