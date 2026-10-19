# The Tailscale exit node VM and its cost-control schedule.

resource "azurerm_linux_virtual_machine" "this" {
  name                = "vm-${local.name_prefix}"
  resource_group_name = var.rg_name
  location            = var.context.location
  size                = var.vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.this.id]

  tags = var.tags

  # Without a key the platform still creates the admin user, just without an
  # authorized key; Tailscale SSH authenticates via tailnet identity instead.
  dynamic "admin_ssh_key" {
    for_each = var.admin_ssh_public_key != "" ? [1] : []
    content {
      username   = var.admin_username
      public_key = var.admin_ssh_public_key
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.vm_image.publisher
    offer     = var.vm_image.offer
    sku       = var.vm_image.sku
    version   = var.vm_image.version
  }

  custom_data = base64encode(local.cloud_init)
}

# Daily auto-shutdown keeps the ephemeral exit node from accruing cost when
# left running. Tearing the node down entirely is done via terraform destroy.
resource "azurerm_dev_test_global_vm_shutdown_schedule" "this" {
  count = var.enable_auto_shutdown ? 1 : 0

  virtual_machine_id    = azurerm_linux_virtual_machine.this.id
  location              = azurerm_linux_virtual_machine.this.location
  enabled               = true
  daily_recurrence_time = replace(var.auto_shutdown_time, ":", "")
  timezone              = var.auto_shutdown_timezone

  notification_settings {
    enabled = false
  }

  tags = var.tags
}
