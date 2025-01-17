/*
  Creates and manages Azure Virtual Machine scale set.
*/

variable "vm_count" {}
variable "vm_name_prefix" {}
variable "image_publisher" {}
variable "image_offer" {}
variable "image_sku" {}
variable "image_version" {}
variable "resource_group_name" {}
variable "location" {}
variable "vm_size" {}
variable "subnet_id" {}
variable "login_username" {}
variable "os_disk_caching" {}
variable "os_storage_account_type" {}
variable "ssh_key_path" {}
variable "vnet_availability_zones" {}
variable "prefix_length" {}
variable "bastion_asg_id" {}

data "local_sensitive_file" "itself" {
  filename = var.ssh_key_path
}

# Manages a Public IP Prefix
resource "azurerm_public_ip_prefix" "itself" {
  name                = "${var.vm_name_prefix}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  prefix_length       = var.prefix_length
}

# Creates azure linux virtual machine with uniform mode
resource "azurerm_linux_virtual_machine_scale_set" "itself" {
  name                = var.vm_name_prefix
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.vm_size
  instances           = var.vm_count
  admin_username      = var.login_username
  zones               = var.vnet_availability_zones
  zone_balance        = length(var.vnet_availability_zones) > 1 ? true : false

  admin_ssh_key {
    username   = var.login_username
    public_key = data.local_sensitive_file.itself.content
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  os_disk {
    caching              = var.os_disk_caching
    storage_account_type = var.os_storage_account_type
  }

  network_interface {
    name    = format("%s-nic", var.vm_name_prefix)
    primary = true

    ip_configuration {
      name                           = format("%s-ip-config", var.vm_name_prefix)
      primary                        = true
      subnet_id                      = var.subnet_id
      application_security_group_ids = var.bastion_asg_id

      public_ip_address {
        name                = var.vm_name_prefix
        public_ip_prefix_id = azurerm_public_ip_prefix.itself.id
      }
    }
  }
}

output "instance_public_ips" {
  value = cidrhost(azurerm_public_ip_prefix.itself.ip_prefix, 0)
}

output "instance_ids" {
  value = azurerm_linux_virtual_machine_scale_set.itself[*].id
}
