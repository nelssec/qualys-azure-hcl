locals {
  dns_suffixes = {
    AzureCloud = {
      keyvault   = "privatelink.vaultcore.azure.net"
      blob       = "privatelink.blob.core.windows.net"
      cosmos     = "privatelink.documents.azure.com"
      web        = "privatelink.azurewebsites.net"
      servicebus = "privatelink.servicebus.windows.net"
    }
    AzureUSGovernment = {
      keyvault   = "privatelink.vaultcore.usgovcloudapi.net"
      blob       = "privatelink.blob.core.usgovcloudapi.net"
      cosmos     = "privatelink.documents.azure.us"
      web        = "privatelink.azurewebsites.us"
      servicebus = "privatelink.servicebus.usgovcloudapi.net"
    }
    AzureChinaCloud = {
      keyvault   = "privatelink.vaultcore.azure.cn"
      blob       = "privatelink.blob.core.chinacloudapi.cn"
      cosmos     = "privatelink.documents.azure.cn"
      web        = "privatelink.chinacloudsites.cn"
      servicebus = "privatelink.servicebus.chinacloudapi.cn"
    }
  }

  dns = local.dns_suffixes[var.target_cloud]
}

resource "azurerm_private_dns_zone" "keyvault" {
  name                = local.dns.keyvault
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "blob" {
  name                = local.dns.blob
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "cosmos" {
  name                = local.dns.cosmos
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "servicebus" {
  name                = local.dns.servicebus
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "keyvault-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = var.service_vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "blob-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = var.service_vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "cosmos" {
  name                  = "cosmos-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.cosmos.name
  virtual_network_id    = var.service_vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "servicebus" {
  name                  = "servicebus-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.servicebus.name
  virtual_network_id    = var.service_vnet_id
  registration_enabled  = false
  tags                  = var.tags
}
