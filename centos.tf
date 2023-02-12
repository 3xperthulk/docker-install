provider "azurerm" {
  features {}

  subscription_id = "bb1bb7fb-1a10-4932-ad07-6c495a180b42"
  client_id       = "011e98cc-6b14-43bd-b77e-840ff5f547bc"
  client_secret   = "THA8Q~kooso1Jp5JqVhn.zx5TxmC7AU_hswclb_r"        
  tenant_id       = "9ebf3598-ad1d-4b7d-a695-052c047690e0"
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "myterraformgroup" {
    name     = "myResourceGroup"
    location = "eastus"

    tags = {
        environment = "Terraform Demo"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.myterraformgroup.name

    tags = {
        environment = "Terraform Demo"
    }
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
    name                 = "mySubnet"
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    count                        = 1
    name                         = "myPublicIP${count.index}"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.myterraformgroup.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Terraform Demo"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "myNetworkSecurityGroup"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.myterraformgroup.name

    security_rule {
        name                       = "INBOUND"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "OUTBOUND"
        priority                   = 1002
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Terraform Demo"
    }
}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
    count                     = 1
    name                      = "myNIC${count.index}"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.myterraformgroup.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.myterraformsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.myterraformpublicip.*.id[count.index]  #[element(azurerm_public_ip.myterraformsubnet.*.id, count.index)]    }

    tags = {
        environment = "Terraform Demo"
    }
}


# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "myterraformnic" {
    count = 1
    network_interface_id      = azurerm_network_interface.myterraformnic.*.id[count.index]
    network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.myterraformgroup.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.myterraformgroup.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Terraform Demo"
    }
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "myterraformvm" {
    count                 = 1
    name                  = "kafka${count.index}"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.myterraformgroup.name
    network_interface_ids = [element(azurerm_network_interface.myterraformnic.*.id, count.index)]
    size                  = "Standard_B4ms"
    computer_name         = "kafka${count.index}"
    admin_username        = "kafkaadmin"
    disable_password_authentication = true

    os_disk {
        name              = "myOsDisk${count.index}"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "OpenLogic"
        offer     = "CentOS"
        sku       = "7.5"
        version   = "latest"
    }


    admin_ssh_key {
        username       = "kafkaadmin"
        public_key     = file("~/.ssh/id_rsa.pub")
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    provisioner "remote-exec" {
     connection {
        user = "kafkaadmin"
        type = "ssh"
        private_key = file("~/.ssh/id_rsa")
        timeout = "20m"
        agent = false
        host = self.public_ip_address
    }
    inline = [
      "sleep 60",
      "sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo",
      "sudo yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin git -y",
      "sudo usermod -aG docker kafkaadmin",
      "sudo systemctl daemon-reload",
      "exit 0",
    ]
  }
    provisioner "remote-exec" {
     connection {
        user = "kafkaadmin"
        type = "ssh"
        private_key = file("~/.ssh/id_rsa")
        timeout = "20m"
        agent = false
        host = self.public_ip_address
    }
    inline = [
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo curl -SL https://github.com/docker/compose/releases/download/v2.15.1/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose",
      "sudo chmod +x /usr/local/bin/docker-compose",
      "sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose",
      "git clone https://github.com/confluentinc/training-administration-src.git confluent-admin",
      "docker-compose -f /home/kafkaadmin/confluent-admin/docker-compose.yml up -d",
    ]
  }
    tags = {
        environment = "Terraform Demo"
    }
}
