variable "resource_group_name" {
  type        = string
  description = "Resource Group name"
}

variable location {
  type        = string
  description = "Location in which to deploy the network"
}

variable "vnet_name" {
  type        = string
  description = "VNET name"
}

variable "address_space" {
  type        = list(string)
  description = "VNET address space"
}

variable subnets {
    type = list(object({
    name             = string
    address_prefixes = list(string)
  }))
  description = "Subnets configuration"
}