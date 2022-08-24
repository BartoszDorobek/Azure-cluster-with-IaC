resource "azurerm_resource_group" "vm" {
  name     = var.vm_resource_group_name
  location = var.location
}

resource "azurerm_resource_group" "aks" {
  name     = var.aks_resource_group_name
  location = var.location
}

//---------------------------VNETs------------------------------
module "vm_network" {
  source              = "./modules/vnet"
  resource_group_name = azurerm_resource_group.vm.name
  location            = var.location
  vnet_name           = var.vm_vnet_name
  address_space       = ["10.0.0.0/22"]
  subnets = [
    {
      name : "AzureBastionSubnet"
      address_prefixes : ["10.0.0.0/24"]
    },
    {
      name : "vm-subnet"
      address_prefixes : ["10.0.1.0/24"]
    }
  ]
}

module "aks_network" {
  source              = "./modules/vnet"
  resource_group_name = azurerm_resource_group.aks.name
  location            = var.location
  vnet_name           = var.aks_vnet_name
  address_space       = ["10.0.4.0/22"]
  subnets = [
    {
      name : "aks-subnet"
      address_prefixes : ["10.0.5.0/24"]
    }
  ]
}

//---------------------------PEERING------------------------------
module "peering" {
  source              = "./modules/peering"
  vnet_1_name         = var.vm_vnet_name
  vnet_1_id           = module.vm_network.vnet_id
  vnet_1_rg           = azurerm_resource_group.vm.name
  vnet_2_name         = var.aks_vnet_name
  vnet_2_id           = module.aks_network.vnet_id
  vnet_2_rg           = azurerm_resource_group.aks.name
  peering_name_1_to_2 = "peering_vm_acr" //Hub to Spoke
  peering_name_2_to_1 = "peering_acr_vm" //Spoke to Hub
}

//---------------------------CLUSTER------------------------------
resource "azurerm_kubernetes_cluster" "privateaks" {
  name                    = "private-aks"
  location                = var.location
  kubernetes_version      = "1.22"
  resource_group_name     = azurerm_resource_group.aks.name
  dns_prefix              = "private-aks"
  private_cluster_enabled = true

  default_node_pool {
    name           = "default"
    node_count     = var.nodepool_nodes_count
    vm_size        = var.nodepool_vm_size
    vnet_subnet_id = module.aks_network.subnet_ids["aks-subnet"]
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    docker_bridge_cidr = var.network_docker_bridge_cidr
    dns_service_ip     = var.network_dns_service_ip
    service_cidr       = var.network_service_cidr
    network_plugin = "azure"
    load_balancer_sku = "standard"
  }
}

//---------------------------ACR------------------------------

resource "azurerm_role_assignment" "netcontributor" {
  role_definition_name = "Network Contributor"
  scope                = module.aks_network.subnet_ids["aks-subnet"]
  principal_id         = azurerm_kubernetes_cluster.privateaks.identity[0].principal_id
}

resource "azurerm_container_registry" "acr" {
  name                = "acr1privateaks"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  sku                 = "Premium"
  admin_enabled       = true
}

//---------------------------VM------------------------------

module "jumpbox_vm" {
  source                  = "./modules/jumpbox_vm"
  location                = var.location
  resource_group          = azurerm_resource_group.vm.name
  vnet_id                 = module.vm_network.vnet_id
  subnet_id               = module.vm_network.subnet_ids["vm-subnet"]
  dns_zone_name           = join(".", slice(split(".", azurerm_kubernetes_cluster.privateaks.private_fqdn), 1, length(split(".", azurerm_kubernetes_cluster.privateaks.private_fqdn))))
  dns_zone_resource_group = azurerm_kubernetes_cluster.privateaks.node_resource_group
}