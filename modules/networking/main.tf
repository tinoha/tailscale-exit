locals {
  # Name prefix for resources, based on the deployment context:
  # <project>-<environment>-<location>
  name_prefix = join("-", compact([
    var.context.project,
    var.context.environment,
    var.context.location
  ]))
}

# Virtual network holding the exit node workload. Pure addressing: firewall
# rules and workload resources live with their consumers, not here.

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${local.name_prefix}"
  address_space       = var.vnet_address_space
  location            = var.context.location
  resource_group_name = var.rg_name

  tags = var.tags
}

resource "azurerm_subnet" "this" {
  name                 = "snet-${local.name_prefix}"
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.subnet_address_prefixes
}
