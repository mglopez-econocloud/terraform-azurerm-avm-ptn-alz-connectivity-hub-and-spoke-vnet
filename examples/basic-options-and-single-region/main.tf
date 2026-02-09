terraform {
  required_version = "~> 1.12"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.21"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "random_string" "suffix" {
  length  = 4
  numeric = true
  special = false
  upper   = false
}

locals {
  common_tags = {
    created_by  = "terraform"
    project     = "Azure Landing Zones"
    owner       = "avm"
    environment = "demo"
  }
  resource_groups = {
    hub_primary = {
      name     = "rg-hub-primary-${random_string.suffix.result}"
      location = "northeurope"  //add the region of origin
    }
  }
}

module "resource_groups" {
  source   = "Azure/avm-res-resources-resourcegroup/azurerm"
  version  = "0.2.0"
  for_each = local.resource_groups

  location         = each.value.location
  name             = each.value.name
  enable_telemetry = false
  tags             = local.common_tags
}

# This is the module call
module "test" {
  source = "../../"

  default_naming_convention = {
    virtual_network_name = "vnet-test-${random_string.suffix.result}-$${location}-$${sequence}"
  }
  enable_telemetry = false
  hub_and_spoke_networks_settings = {
    enabled_resources = {
      ddos_protection_plan = false  //If you need to activate it, set it to true.
    }
  }
  hub_virtual_networks = {
    primary = {
      enabled_resources = {  //Choose the network topology; if activated, set to true.
        virtual_network_gateway_express_route = false
        virtual_network_gateway_vpn           = true
        bastion                               = true
        firewall                              = true
        private_dns_zones                     = false
      }
      location                  = local.resource_groups["hub_primary"].location
      default_hub_address_space = "192.168.0.0/16"  //address space selected for the hub network
      default_parent_id         = module.resource_groups["hub_primary"].resource_id
    }
  }
  tags = local.common_tags
}
