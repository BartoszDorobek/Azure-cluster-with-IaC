resource "azurerm_public_ip" "vm_ip" {
  name                = "vm-devbox-ip"
  location            = var.location
  resource_group_name = var.resource_group
  allocation_method   = "Dynamic"
}

resource "azurerm_network_security_group" "vm_nsg" {
  name                = "vm-devbox-nsg"
  location            = var.location
  resource_group_name = var.resource_group

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/24"
    destination_address_prefix = "10.0.1.0/24"
  }
}

resource "azurerm_network_interface" "vm_inf" {
  name                = "vm-devbox-inf"
  location            = var.location
  resource_group_name = var.resource_group

  ip_configuration {
    name                          = "vmInfConfiguration"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "sg_association" {
  network_interface_id      = azurerm_network_interface.vm_inf.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

resource "azurerm_linux_virtual_machine" "jumpbox_vm" {
  name                            = "vm-devbox"
  location                        = var.location
  resource_group_name             = var.resource_group
  network_interface_ids           = [azurerm_network_interface.vm_inf.id]
  size                            = "Standard_DS2_v2"
  computer_name                   = "vm-devbox"
  admin_username                  = var.vm_user
  admin_password                  = var.vm_password
  disable_password_authentication = false

  os_disk {
    name                 = "vm-devbox_OsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  provisioner "remote-exec" {
    connection {
      host     = self.public_ip_address
      type     = "ssh"
      user     = var.vm_user
      password = var.vm_password
      timeout  = "4m"
    }
    
    inline = [
      "sudo apt-get update && sudo apt-get install -y apt-transport-https gnupg2",
      "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -",
      "echo 'deb https://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee -a /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update",
      "sudo apt-get install -y kubectl",
      "sudo apt-get install docker.io -y",
      "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
    ]
  }

  depends_on = [azurerm_network_interface.vm_inf, azurerm_network_security_group.vm_nsg]
}

resource "azurerm_private_dns_zone_virtual_network_link" "hublink" {
  name                  = "hubnetdnsconfig"
  resource_group_name   = var.dns_zone_resource_group
  private_dns_zone_name = var.dns_zone_name
  virtual_network_id    = var.vnet_id
}