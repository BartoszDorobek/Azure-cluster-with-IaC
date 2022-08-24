variable "location" {
  type        = string
  description = "Resources location in Azure"
}

//------------------------------RG------------------------------
variable "vm_resource_group_name" {
  type        = string
  description = "Name of resource group which contains virtual machine"
}

variable "aks_resource_group_name" {
  type        = string
  description = "Name of resource group for aks cluster which contains container"
} 

//------------------------------VNET------------------------------
variable "aks_vnet_name" {
  type        = string
  description = "AKS VNET name"
}

variable "vm_vnet_name" {
  type        = string
  description = "Hub VNET name"
}

//------------------------------NODES------------------------------
variable "nodepool_nodes_count" {
  description = "Default nodepool nodes count"
}

variable "nodepool_vm_size" {
  description = "Default nodepool VM size"
}
//------------------------------NETWORK------------------------------
variable "network_docker_bridge_cidr" {
  description = "CNI Docker bridge cidr"
  default     = "172.17.0.1/16"
}

variable "network_dns_service_ip" {
  description = "CNI DNS service IP"
  default     = "10.2.0.10"
}

variable "network_service_cidr" {
  description = "CNI service cidr"
  default     = "10.2.0.0/24"
}

