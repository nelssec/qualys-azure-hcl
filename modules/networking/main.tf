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

  target_locations_indexed = { for idx, loc in var.target_locations : loc => idx }
}

resource "azurerm_network_security_group" "scanner" {
  name                = "qualys-scanner-nsg-${var.deployment_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowHTTPSOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSHOutbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "service" {
  name                = "qualys-service-nsg-${var.deployment_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowHTTPSInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "private_endpoints" {
  name                = "qualys-pe-nsg-${var.deployment_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowVnetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "service" {
  name                = "qualys-service-vnet-${var.deployment_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.0.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "function_app" {
  name                 = "function-app-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.service.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "function-app-delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "function_app" {
  subnet_id                 = azurerm_subnet.function_app.id
  network_security_group_id = azurerm_network_security_group.service.id
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "private-endpoints-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.service.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}

resource "azurerm_virtual_network" "scanner" {
  for_each = local.target_locations_indexed

  name                = "qualys-scanner-vnet-${each.key}-${var.deployment_id}"
  location            = each.key
  resource_group_name = var.resource_group_name
  address_space       = ["10.${each.value + 1}.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "scanner" {
  for_each = local.target_locations_indexed

  name                 = "scanner-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.scanner[each.key].name
  address_prefixes     = ["10.${each.value + 1}.1.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "scanner" {
  for_each = local.target_locations_indexed

  subnet_id                 = azurerm_subnet.scanner[each.key].id
  network_security_group_id = azurerm_network_security_group.scanner.id
}

resource "azurerm_virtual_network_peering" "scanner_to_service" {
  for_each = local.target_locations_indexed

  name                         = "scanner-to-service-${each.key}"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.scanner[each.key].name
  remote_virtual_network_id    = azurerm_virtual_network.service.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "service_to_scanner" {
  for_each = local.target_locations_indexed

  name                         = "service-to-scanner-${each.key}"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.service.name
  remote_virtual_network_id    = azurerm_virtual_network.scanner[each.key].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
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
  virtual_network_id    = azurerm_virtual_network.service.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "blob-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.service.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "cosmos" {
  name                  = "cosmos-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.cosmos.name
  virtual_network_id    = azurerm_virtual_network.service.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "servicebus" {
  name                  = "servicebus-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.servicebus.name
  virtual_network_id    = azurerm_virtual_network.service.id
  registration_enabled  = false
  tags                  = var.tags
}
