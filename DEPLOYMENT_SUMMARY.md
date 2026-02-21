# EAM Infrastructure Restructuring - ARO Implementation Summary

## Overview
Successfully restructured the EAM (Enterprise Asset Management) Bicep infrastructure to:
- Replace compute-based infrastructure with Azure Red Hat OpenShift (ARO)
- Remove the compute folder containing VMs and load balancers
- Add ARO master and worker subnets
- Enable Microsoft Defender for Servers
- Maintain SQL Managed Instance and storage infrastructure

## Changes Made

### 1. ✅ Created New Modules

#### ARO Module ([infrastructure/modules/aro/aro.bicep](infrastructure/modules/aro/aro.bicep))
- Deploys Azure Red Hat OpenShift cluster
- Configures master and worker node pools
- Sets up ingress profiles and API server visibility
- Outputs: Cluster ID, API Server URL, Ingress IP, Console URL

#### Defender Module ([infrastructure/modules/security/defender.bicep](infrastructure/modules/security/defender.bicep))
- Enables Microsoft Defender for Servers, SQL Servers, and App Services
- Configurable pricing tier (Standard)
- Optional Log Analytics integration for security data

### 2. ✅ Updated Networking Infrastructure

#### New VNet Module: vnet_4subnet.bicep ([infrastructure/modules/networking/virtual_network/vnet_4subnet.bicep](infrastructure/modules/networking/virtual_network/vnet_4subnet.bicep))
- **Old Structure**: 3 subnets (app, data, pep)
- **New Structure**: 4 subnets (master, worker, data, pep)
- Master subnet: 10.90.0.0/24 (for ARO control plane)
- Worker subnet: 10.90.1.0/24 (for ARO application nodes)
- Data subnet: 10.90.2.0/24 (for SQL Managed Instance)
- PEP subnet: 10.90.3.0/24 (for private endpoints)

#### Updated NSG Rules ([infrastructure/modules/networking/network_security_group/nsg.bicep](infrastructure/modules/networking/network_security_group/nsg.bicep))
**Removed**: App NSG (for VMs)

**Added**:
- **Master NSG**: Allows API server (port 6443) and NodePort range (30000-32767)
- **Worker NSG**: Allows HTTP (80), HTTPS (443), and NodePort range (30000-32767)

**Updated**:
- **Data NSG**: Now accepts connections from both master and worker subnets (instead of just app subnet)
- **PEP NSG**: Now accepts connections from both master and worker subnets for SQL/storage access

### 3. ✅ Updated Main Bicep Files

#### networking.main.bicep
- Replaced `vnet_3subnet` with `vnet_4subnet` module
- Updated subnet parameters from appSubnet to masterSubnet/workerSubnet
- Updated NSG names from `appNsgName` to `masterNsgName`/`workerNsgName`
- New outputs: `masterSubnetId`, `workerSubnetId` (instead of `appSubnetId`)

#### app.main.bicep
- **Removed**: VM modules (vm1, vm2), Load Balancer module, SSH key parameters
- **Added**: ARO module deployment
- **Kept**: 
  - Storage Accounts (2x for file and integration data)
  - Application Insights
  - SQL Managed Instance (optional deployment)
  - Private Endpoints for storage
  - Managed Identity
  - Defender for Servers
- New outputs: ARO cluster details (API Server URL, Ingress IP, Console URL)

#### ops.main.bicep (migrated)
- Operations resources (log analytics, recovery vault, backup vault) have been migrated into `app.main.bicep` and will be created as part of the application deployment

### 4. ✅ Created Orchestration File

#### infrastructure/main.bicep
- New subscription-level orchestration template
- Creates three resource groups:
  - eam-net-tst-ae-rg (Networking)
  - eam-app-tst-ae-rg (Application/ARO)
  - (Operations resources now deploy into `eam-app-tst-ae-rg`)
- Orchestrates deployments in sequence:
  1. Networking (creates VNet with 4 subnets)
  2. Application (deploys ARO cluster and operations resources)
- Passes outputs from networking to app deployment

### 5. ✅ Updated Parameter File

[infrastructure/environments/dev/main.dev.bicepparam](infrastructure/environments/dev/main.dev.bicepparam)
- **Removed**: App subnet parameters (appSubnetName, appSubnetPrefix)
- **Added**: Master and worker subnet parameters
- **Updated**: NSG names for master/worker
- **Updated**: ARO cluster configuration parameters
- **Removed**: VM-related parameters (vm names, SSH keys, load balancer)
- **Added**: ARO cluster version, initial configuration
- **Kept**: Storage accounts, SQL MI, monitoring, security settings

## Subnet Configuration

### Old Layout
```
VNet: 10.90.0.0/19
├── App Subnet: 10.90.0.0/24
├── Data Subnet: 10.90.1.0/24
└── PEP Subnet: 10.90.2.0/24
```

### New Layout
```
VNet: 10.90.0.0/19
├── Master Subnet (ARO): 10.90.0.0/24
├── Worker Subnet (ARO): 10.90.1.0/24
├── Data Subnet: 10.90.2.0/24
└── PEP Subnet: 10.90.3.0/24
```

## Security Configuration

### Defender for Servers
- ✅ Enabled by default (configurable via parameter)
- ✅ Applies to: VirtualMachines, SqlServers, AppServices
- ✅ Pricing Tier: Standard

### Network Security
- ✅ Master NSG: Allows API server and node communication
- ✅ Worker NSG: Allows ingress traffic (HTTP/HTTPS) and NodePort services
- ✅ Data NSG: Allows SQL connections from ARO subnets
- ✅ PEP NSG: Allows access to storage and database private endpoints

## Deployment Instructions

### Prerequisites
1. Azure CLI with Bicep support
2. Service Principal with appropriate permissions
3. Three resource groups (or allow script to create them)
4. Existing Key Vault for credentials

### Deploy All Resources
```bash
# Set variables
az deployment sub create \
  --template-file infrastructure/main.bicep \
  --parameters infrastructure/environments/dev/main.dev.bicepparam \
  --location australiaeast \
  --name eam-aro-deployment
```

### Deploy Individual Components
```bash
# Networking only
az deployment group create \
  --resource-group eam-net-tst-ae-rg \
  --template-file networking.main.bicep \
  --parameters infrastructure/environments/dev/main.dev.bicepparam

# Application/ARO only (after networking)
az deployment group create \
  --resource-group eam-app-tst-ae-rg \
  --template-file app.main.bicep \
  --parameters infrastructure/environments/dev/main.dev.bicepparam \
  --parameters masterSubnetId=/subscriptions/.../subnets/master

# Operations
# The operations resources are now included in `app.main.bicep`. Deploy the application resource group to create operations resources as part of the app deployment.
```bash
# Deploy application + operations
az deployment group create \
  --resource-group eam-app-tst-ae-rg \
  --template-file app.main.bicep \
  --parameters infrastructure/environments/dev/main.dev.bicepparam \
  --parameters masterSubnetId=/subscriptions/.../subnets/master
```
```

## Validation Status

✅ **All Bicep files compile successfully** with no errors
⚠️ Minor warnings only:
- Unused parameters in modules (by design for extensibility)
- These do not affect deployment

## Files to Clean Up

⚠️ **NOTE**: The `/infrastructure/modules/compute/` folder is no longer needed
- Contains: `virtual_machine.bicep`, `loadbalancer.bicep`
- **Action**: Please delete this folder manually as it's no longer referenced
- Recommendation: Remove from git repository

## Post-Deployment Tasks

1. **ARO Credentials**: Retrieve credentials from ARO cluster
   ```bash
  az aro list-credentials --name eam-app-tst-ae-aro --resource-group eam-app-tst-ae-rg
   ```

2. **Database Connection**: Update connection strings for SQL MI private endpoint

3. **Monitoring**: Configure Log Analytics for ARO cluster insights

4. **Backup Policies**: Set up backup policies for VMSS and persistent volumes

5. **ARO Console Access**: Use the console URL to configure OpenShift resources

## Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│                   Azure Subscription                 │
└─────────────────────────────────────────────────────┘
              │
         ┌────┴────┬─────────────┐
         │          │             │
    ┌────▼───┐ ┌───▼──┐ ┌───────▼───┐
    │Networking│ │ App  │ │  Operations│
    │   RG     │ │  RG  │ │    RG      │
    └────┬───┘ └───┬──┘ └───────┬───┘
         │         │            │
         ▼         ▼            ▼
    ┌─────────┐ ┌──────────┐ ┌──────────────┐
    │VNet 4sn │ │ARO Cluster│ │Backup Vaults │
    │NSGs/RTB │ │Storage    │ │Log Analytics │
    │         │ │AppInsights│ │              │
    └─────────┘ └──────────┘ └──────────────┘
```

## Parameter Reference

Key parameters in `main.dev.bicepparam`:
- `environment`: 'dev'
- `location`: 'australiaeast'
- `aroClusterName`: 'eam-app-tst-ae-aro'
- `aroClusterVersion`: '4.14.0'
- `masterSubnetPrefix`: '10.90.0.0/24'
- `workerSubnetPrefix`: '10.90.1.0/24'
- `enableDefender`: true
- `deploySqlMi`: false (optional)

## Support Files Location
- Main templates: `JHG/*.bicep`
- Modules: `JHG/infrastructure/modules/`
- Parameters: `JHG/infrastructure/environments/dev/`

---

✅ **Status**: Ready for deployment
🔒 **Security**: Defender for Servers enabled
📊 **Monitoring**: Log Analytics configured
🚀 **Container Platform**: ARO with 3 worker nodes
💾 **Data**: SQL MI and Storage Accounts configured
