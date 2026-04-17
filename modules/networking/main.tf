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

  create_service_vnet = var.existing_service_vnet_id == null

  # Parse existing VNet ID to extract name and resource group for peering
  existing_vnet_parts = var.existing_service_vnet_id != null ? split("/", var.existing_service_vnet_id) : []
  existing_vnet_name  = length(local.existing_vnet_parts) > 8 ? local.existing_vnet_parts[8] : ""
  existing_vnet_rg    = length(local.existing_vnet_parts) > 4 ? local.existing_vnet_parts[4] : ""

  service_vnet_id   = local.create_service_vnet ? azurerm_virtual_network.service[0].id : var.existing_service_vnet_id
  service_vnet_name = local.create_service_vnet ? azurerm_virtual_network.service[0].name : local.existing_vnet_name
  service_vnet_rg   = local.create_service_vnet ? var.resource_group_name : local.existing_vnet_rg
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

resource "azurerm_network_security_group" "proxy_function_app" {
  name                = "qualys-proxy-fa-nsg-${var.deployment_id}"
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
}

resource "azurerm_network_security_group" "private_storage" {
  name                = "qualys-private-storage-nsg-${var.deployment_id}"
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
  count = local.create_service_vnet ? 1 : 0

  name                = "qualys-service-vnet-${var.deployment_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_address_prefix]
  tags                = var.tags
}

# Service VNet subnets use cidrsubnet from the parameterized prefix
# Subnet 0: function-app (/24)
resource "azurerm_subnet" "function_app" {
  count = var.existing_function_app_subnet_id == null ? 1 : 0

  name                 = "function-app-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.service[0].name
  address_prefixes     = [cidrsubnet(var.vnet_address_prefix, 4, 0)]

  delegation {
    name = "function-app-delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "function_app" {
  count = var.existing_function_app_subnet_id == null ? 1 : 0

  subnet_id                 = azurerm_subnet.function_app[0].id
  network_security_group_id = azurerm_network_security_group.service.id
}

# Subnet 1: private-endpoints (/24)
resource "azurerm_subnet" "private_endpoints" {
  count = var.existing_private_endpoint_subnet_id == null ? 1 : 0

  name                 = "private-endpoints-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.service[0].name
  address_prefixes     = [cidrsubnet(var.vnet_address_prefix, 4, 1)]
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  count = var.existing_private_endpoint_subnet_id == null ? 1 : 0

  subnet_id                 = azurerm_subnet.private_endpoints[0].id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}

# Per-location scanner VNets
resource "azurerm_virtual_network" "scanner" {
  for_each = local.target_locations_indexed

  name                = "qualys-scanner-vnet-${each.key}-${var.deployment_id}"
  location            = each.key
  resource_group_name = var.resource_group_name
  address_space       = [cidrsubnet(var.scanner_vnet_address_prefix, 0, 0)]
  tags                = var.tags
}

resource "azurerm_subnet" "scanner" {
  for_each = local.target_locations_indexed

  name                 = "scanner-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.scanner[each.key].name
  address_prefixes     = [cidrsubnet(cidrsubnet(var.scanner_vnet_address_prefix, 0, 0), 8, 1)]
}

resource "azurerm_subnet_network_security_group_association" "scanner" {
  for_each = local.target_locations_indexed

  subnet_id                 = azurerm_subnet.scanner[each.key].id
  network_security_group_id = azurerm_network_security_group.scanner.id
}

# Per-location function app subnets in scanner VNets
resource "azurerm_subnet" "regional_function_app" {
  for_each = local.target_locations_indexed

  name                 = "proxy-function-app-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.scanner[each.key].name
  address_prefixes     = [cidrsubnet(cidrsubnet(var.scanner_vnet_address_prefix, 0, 0), 10, 8)]

  delegation {
    name = "proxy-function-app-delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "regional_function_app" {
  for_each = local.target_locations_indexed

  subnet_id                 = azurerm_subnet.regional_function_app[each.key].id
  network_security_group_id = azurerm_network_security_group.proxy_function_app.id
}

# Per-location private storage subnets in scanner VNets
resource "azurerm_subnet" "regional_private_storage" {
  for_each = local.target_locations_indexed

  name                 = "private-storage-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.scanner[each.key].name
  address_prefixes     = [cidrsubnet(cidrsubnet(var.scanner_vnet_address_prefix, 0, 0), 10, 9)]
}

resource "azurerm_subnet_network_security_group_association" "regional_private_storage" {
  for_each = local.target_locations_indexed

  subnet_id                 = azurerm_subnet.regional_private_storage[each.key].id
  network_security_group_id = azurerm_network_security_group.private_storage.id
}

resource "azurerm_virtual_network_peering" "scanner_to_service" {
  for_each = local.target_locations_indexed

  name                         = "scanner-to-service-${each.key}"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.scanner[each.key].name
  remote_virtual_network_id    = local.service_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "service_to_scanner" {
  for_each = local.target_locations_indexed

  name                         = "service-to-scanner-${each.key}"
  resource_group_name          = local.service_vnet_rg
  virtual_network_name         = local.service_vnet_name
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
  virtual_network_id    = local.service_vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "blob-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = local.service_vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "cosmos" {
  name                  = "cosmos-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.cosmos.name
  virtual_network_id    = local.service_vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "servicebus" {
  name                  = "servicebus-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.servicebus.name
  virtual_network_id    = local.service_vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

# DNS zone links for regional scanner VNets
resource "azurerm_private_dns_zone_virtual_network_link" "keyvault_scanner" {
  for_each = local.target_locations_indexed

  name                  = "keyvault-scanner-link-${each.key}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.scanner[each.key].id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_scanner" {
  for_each = local.target_locations_indexed

  name                  = "blob-scanner-link-${each.key}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.scanner[each.key].id
  registration_enabled  = false
  tags                  = var.tags
}
