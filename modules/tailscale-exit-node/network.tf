# Public IPs, NIC, NSG and NSG association for the exit node VM.
#
# These are lifecycle-bound to the VM (replaced with it) and therefore live
# here rather than in the shared networking module, which owns addressing
# only. The NSG is always attached to the NIC and denies all inbound traffic
# from the internet (Azure's default rules); the only optional exception is
# the feature-flagged SSH allow rule.

resource "azurerm_public_ip" "ipv4" {
  count = var.enable_public_ipv4_address ? 1 : 0

  name                = "pip-${local.name_prefix}-v4"
  resource_group_name = var.rg_name
  location            = var.context.location
  allocation_method   = "Static"
  ip_version          = "IPv4"
  sku                 = "Standard"

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_public_ip" "ipv6" {
  count = var.enable_public_ipv6_address ? 1 : 0

  name                = "pip-${local.name_prefix}-v6"
  resource_group_name = var.rg_name
  location            = var.context.location
  allocation_method   = "Static"
  ip_version          = "IPv6"
  sku                 = "Standard"

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_network_security_group" "this" {
  name                = "nsg-${local.name_prefix}"
  location            = var.context.location
  resource_group_name = var.rg_name

  tags = var.tags
}

resource "azurerm_network_security_rule" "allow_ssh" {
  count = var.enable_ssh_access ? 1 : 0

  name                        = "AllowInboundSSH"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.rg_name
  network_security_group_name = azurerm_network_security_group.this.name
}

resource "azurerm_network_interface" "this" {
  name                  = "nic-${local.name_prefix}"
  location              = var.context.location
  resource_group_name   = var.rg_name
  ip_forwarding_enabled = true

  # Primary IP configuration for the NIC, including subnet and public IP association
  ip_configuration {
    name                          = "ipconfig-v4"
    private_ip_address_version    = "IPv4"
    primary                       = true
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.enable_public_ipv4_address ? azurerm_public_ip.ipv4[0].id : null
  }

  # Secondary IP configuration for IPv6, including subnet and public IP association
  ip_configuration {
    name                          = "ipconfig-v6"
    primary                       = false
    subnet_id                     = var.subnet_id
    private_ip_address_version    = "IPv6"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.enable_public_ipv6_address ? azurerm_public_ip.ipv6[0].id : null
  }

  tags = var.tags
}

resource "azurerm_network_interface_security_group_association" "this" {
  network_interface_id      = azurerm_network_interface.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}
