# Qualys Azure Snapshot Scanner - Terraform

Terraform HCL deployment for the Qualys Azure Snapshot Scanner. Deploys a serverless scanning infrastructure that discovers Azure VMs, creates temporary disk snapshots, and runs Qualys vulnerability scans — all orchestrated by Logic Apps and Azure Functions.

## Architecture

```
                         ┌─────────────────┐
                         │   Qualys API    │
                         └────────┬────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │     Azure Function App     │
                    │       (Node.js 18)         │
                    └─────────────┬─────────────┘
                                  │
              ┌───────────────────┼───────────────────┐
              │                   │                   │
     ┌────────┴────────┐ ┌───────┴───────┐ ┌────────┴────────┐
     │   21 Logic App  │ │   Cosmos DB   │ │   Key Vault     │
     │   Workflows     │ │  (Serverless) │ │   (Secrets)     │
     └────────┬────────┘ └───────────────┘ └─────────────────┘
              │
    ┌─────────┼─────────┐
    │         │         │
  Discover  Scan    Cleanup
   VMs     Disks   Resources
```

**Workflow pipeline:** Discovery (poll or event-based) -> Snapshot creation -> Disk creation -> Scanner VM provisioning -> Qualys scan -> Cleanup

All PaaS services use private endpoints. Scanner VMs are isolated in per-region VNets with peering back to the central service network.

## Prerequisites

- Terraform >= 1.5.0
- Azure CLI authenticated (`az login`)
- Qualys subscription token and API endpoint
- Permissions to create resources, RBAC roles, and managed identities in the target subscription

## Quick Start

```bash
git clone https://github.com/nelssec/qualys-azure-hcl.git
cd qualys-azure-hcl

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

terraform init
terraform plan
terraform apply
```

## Configuration

### Required Variables

| Variable | Description |
|----------|-------------|
| `subscription_id` | Azure subscription ID |
| `location` | Azure region for central infrastructure |
| `qualys_endpoint` | Qualys platform API endpoint (e.g., `https://gateway.qg1.apps.qualys.com`) |
| `qualys_subscription_token` | Qualys subscription token (sensitive) |
| `target_locations` | Azure regions to scan VMs in |

### Scanning Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `scan_interval_hours` | `24` | Hours between scan cycles |
| `poll_interval_hours` | `4` | Hours between VM discovery cycles |
| `location_concurrency` | `5` | Maximum concurrent region scans |
| `scanners_per_location` | `1` | Scanner VMs per region |
| `event_based_discovery` | `false` | Use event-based discovery instead of polling |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `resource_group_name` | `qualys-scanner-rg` | Resource group name |
| `target_cloud` | `AzureCloud` | Cloud environment (`AzureCloud`, `AzureUSGovernment`, `AzureChinaCloud`) |
| `debug_enabled` | `false` | Enable Application Insights |
| `app_version` | `3.20.0` | Scanner application version |
| `custom_deployment_id` | Auto-generated | Custom deployment ID (5 chars) |
| `role_boundary` | Subscription scope | Management group ID for tenant-wide scanning |
| `tags` | `{}` | Additional resource tags as key-value pairs |

### Example terraform.tfvars

```hcl
subscription_id           = "00000000-0000-0000-0000-000000000000"
location                  = "eastus"
qualys_endpoint           = "https://gateway.qg1.apps.qualys.com"
qualys_subscription_token = "your-token-here"
target_locations          = ["eastus", "westus2", "westeurope"]

scan_interval_hours   = 24
poll_interval_hours   = 4
location_concurrency  = 5
scanners_per_location = 1

tags = {
  Environment = "Production"
  Department  = "Security"
}
```

The `qualys_subscription_token` can also be passed via environment variable to avoid storing it in a file:

```bash
export TF_VAR_qualys_subscription_token="your-token-here"
terraform apply
```

## Modules

| Module | Description |
|--------|-------------|
| `roles` | Custom RBAC role definitions for Function App, Logic App, and scanner |
| `security` | Managed identities, Key Vaults, disk encryption sets |
| `networking` | VNets, subnets, NSGs, VNet peering, private DNS zones |
| `storage` | Storage account, blob container, Service Bus namespace |
| `cosmos` | Cosmos DB account (serverless), database, and containers |
| `keyvault-pe` | Key Vault private endpoint |
| `function-app` | App Service Plan, Function App, optional Application Insights |
| `logic-apps` | 21 Logic App workflows orchestrating the scanning pipeline |

## Providers

| Provider | Version | Purpose |
|----------|---------|---------|
| `azurerm` | `~> 4.0` | Azure Resource Manager resources |
| `azapi` | `~> 2.0` | Logic App workflow definitions |
| `random` | `~> 3.5` | Deployment ID generation |
| `http` | `~> 3.4` | Auto-detect deployer IP for Key Vault firewall |

## Security

- **Managed identities** — no stored credentials for Azure service-to-service auth
- **Private endpoints** — Cosmos DB, Key Vault, and Storage are not publicly accessible
- **Key Vault firewalls** — default deny with deployer IP auto-whitelisted during deployment
- **Customer-managed encryption** — per-region disk encryption key vaults with RSA-2048 keys
- **Network isolation** — scanner VMs run in dedicated VNets with NSGs
- **RBAC** — custom roles scoped to subscription or management group boundary

## Multi-Region

Each entry in `target_locations` creates:
- A scanner VNet (`10.N.0.0/16`) with peering to the central service network
- A disk encryption Key Vault with RSA-2048 key
- A disk encryption set

Scanner VMs are provisioned in the target region to scan local VMs, avoiding cross-region data transfer.

## Outputs

| Output | Description |
|--------|-------------|
| `deployment_id` | Generated deployment ID used in resource naming |
| `resource_group_name` | Resource group name |
| `scanner_identity` | Scanner managed identity details (id, client_id, principal_id) |
| `key_vault` | Key Vault name and URI |
| `function_app` | Function App name and hostname |
| `cosmos_db` | Cosmos DB name and endpoint |
| `storage_account` | Storage account name |
| `logic_app_workflows` | Map of all Logic App workflow names |
