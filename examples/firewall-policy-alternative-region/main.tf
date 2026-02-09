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
      location = "northeurope" //add the region of origin
    }
  }
}

module "resource_groups" {
  source   = "Azure/avm-res-resources-resourcegroup/azurerm"
  version  = "0.2.0"
  for_each = local.resource_groups

  location         = each.value.location
  name             = each.value.name
  enable_telemetry = false //Switch to true to enable telemetry
  tags             = local.common_tags
}

module "base_firewall_policy" {
  source  = "Azure/avm-res-network-firewallpolicy/azurerm"
  version = "0.3.3"

  location            = "uksouth"
  name                = "fwp-global-base-uksouth-001"
  resource_group_name = module.resource_groups["hub_primary"].name
  enable_telemetry    = false  //Switch to true to enable telemetry
  firewall_policy_sku = "basic"  //modify if you choose basic or premium
  tags                = local.common_tags
}

# This is the module call
module "test" {
  source = "../../"

  enable_telemetry = false //Switch to true to enable telemetry
  hub_and_spoke_networks_settings = {
    enabled_resources = {
      ddos_protection_plan = false //Switch to true to enable ddos for default false
    }
  }
  hub_virtual_networks = {
    primary = {
      enabled_resources = {
        firewall                              = true //Switch to false for default true
        private_dns_resolver                  = false
        private_dns_zones                     = false
        bastion                               = false //Switch to true for default false
        virtual_network_gateway_express_route = false
        virtual_network_gateway_vpn           = false //Switch to true for default false
      }
      location          = local.resource_groups["hub_primary"].location
      default_parent_id = module.resource_groups["hub_primary"].resource_id
      firewall_policy = {
        name           = "addname"  //add name firewall policy
        location       = "uksouth"  //add region origin 
        base_policy_id = module.base_firewall_policy.resource_id
      }
    }
  }
  tags = local.common_tags
}
