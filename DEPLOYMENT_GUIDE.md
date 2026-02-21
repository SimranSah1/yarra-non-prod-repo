# Azure Deployment Guide for EAM ARO Infrastructure

## Prerequisites Checklist

### 1. Install Required Tools
```bash
# Install Azure CLI (if not already installed)
# For Windows: https://aka.ms/installazurecliwindows
# For Mac: brew install azure-cli
# For Linux: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Verify installation
az --version
bicep --version

# Install/upgrade Bicep CLI
az bicep install
az bicep upgrade
```

### 2. Azure Subscription and Permissions
- [ ] Have an active Azure subscription
- [ ] Have Owner or Contributor role on the subscription
- [ ] Have permissions to create Resource Groups
- [ ] Have permissions to create: VNets, NSGs, ARO clusters, Storage Accounts, SQL MI, etc.

### 3. Prepare Credentials
- [ ] Create/identify Key Vault for storing secrets
- [ ] SQL MI admin password ready (or generate a strong one)
- [ ] ARO pull secret (optional, but required for production)

---

## Step 1: Authenticate to Azure

```bash
# Login to Azure
az login

# If you have multiple subscriptions, select the correct one
az account list --output table
az account set --subscription "YOUR-SUBSCRIPTION-ID"

# Verify you're logged in to correct subscription
az account show
```

---

## Step 2: Validate Bicep Templates Before Deployment

```bash
# Navigate to your project folder
cd "c:\Users\SimranSah\OneDrive - Neudesic\Neudesic Folder\Neudesic folder\Project\2.John Holland\Script\JHG 2_v3_dev - Copy"

# Validate the main template
az bicep build --file JHG/infrastructure/main.bicep

# Validate parameter file syntax
bicep build JHG/infrastructure/main.bicep --outfile template.json

# Preview what will be deployed (optional)
az deployment sub what-if \
  --template-file JHG/infrastructure/main.bicep \
  --parameters JHG/infrastructure/environments/dev/main.dev.bicepparam \
  --location australiaeast
```

---

## Step 3: Review and Update Parameters

Before deploying, review the parameter file:

**File**: `JHG/infrastructure/environments/dev/main.dev.bicepparam`

⚠️ **IMPORTANT CHANGES**:

1. **SQL MI Password** (CRITICAL):
   ```
   param sqlMiAdminPassword = 'P@ssw0rd123!ChangeMe'  // ← CHANGE THIS
   ```
   Replace with a strong password (min 16 chars, uppercase, lowercase, numbers, special chars)

2. **Key Vault Name** (if different):
   ```
  param keyVaultName = 'eam-kv-tst-ae-001'
   ```

3. **Resource Group Names** (optional, customize if needed):
   ```
  param networkingResourceGroupName = 'eam-net-tst-ae-rg'
  param appResourceGroupName = 'eam-app-tst-ae-rg'
  // opsResourceGroupName removed; operations/backup resources deploy into `eam-app-tst-ae-rg`
   ```

4. **Owner Tag** (update email):
   ```
   param tags = {
     owner: 'your.email@company.com'  // ← Update this
     environment: 'dev'
     project: 'EAM'
   }
   ```

---

## Step 4: Deploy Infrastructure

### Option A: Deploy Everything at Once (Recommended for Testing)

```bash
# Full subscription-level deployment
az deployment sub create \
  --template-file JHG/infrastructure/main.bicep \
  --parameters JHG/infrastructure/environments/dev/main.dev.bicepparam \
  --location australiaeast \
  --name "eam-aro-deploy-$(date +%Y%m%d-%H%M%S)"

# Monitor deployment
# The deployment will create:
# 1. Three resource groups
# 2. All networking infrastructure with ARO subnets
# 3. ARO cluster (this takes 30-45 minutes)
# 4. Storage accounts, SQL MI (optional), backup vaults
```

### Option B: Deploy in Stages (Recommended for Production)

**Stage 1: Deploy Networking Only**
```bash
# Create networking resource group first
az group create \
  --name eam-net-tst-ae-rg \
  --location australiaeast

# Deploy networking
az deployment group create \
  --resource-group eam-net-tst-ae-rg \
  --template-file JHG/networking.main.bicep \
  --parameters JHG/infrastructure/environments/dev/main.dev.bicepparam \
  --name "networking-deploy-$(date +%Y%m%d-%H%M%S)"

# Wait for completion (5-10 minutes)
```

**Stage 2: Deploy Application (ARO)**
```bash
# Create app resource group
az group create \
  --name eam-app-tst-ae-rg \
  --location australiaeast

# Get subnet IDs from networking deployment
MASTER_SUBNET=$(az deployment group show \
  --resource-group eam-net-tst-ae-rg \
  --name "networking-deploy-*" \
  --query properties.outputs.masterSubnetId.value -o tsv)

WORKER_SUBNET=$(az deployment group show \
  --resource-group eam-net-tst-ae-rg \
  --name "networking-deploy-*" \
  --query properties.outputs.workerSubnetId.value -o tsv)

DATA_SUBNET=$(az deployment group show \
  --resource-group eam-net-tst-ae-rg \
  --name "networking-deploy-*" \
  --query properties.outputs.dataSubnetId.value -o tsv)

PEP_SUBNET=$(az deployment group show \
  --resource-group eam-net-tst-ae-rg \
  --name "networking-deploy-*" \
  --query properties.outputs.pepSubnetId.value -o tsv)

# Deploy ARO application
az deployment group create \
  --resource-group eam-app-tst-ae-rg \
  --template-file JHG/app.main.bicep \
  --parameters JHG/infrastructure/environments/dev/main.dev.bicepparam \
  --parameters \
    masterSubnetId="$MASTER_SUBNET" \
    workerSubnetId="$WORKER_SUBNET" \
    dataSubnetId="$DATA_SUBNET" \
    pepSubnetId="$PEP_SUBNET" \
  --name "app-deploy-$(date +%Y%m%d-%H%M%S)"

# Wait for completion (30-45 minutes for ARO cluster)
```

**Stage 3: Operations (migrated)**

The operations resources (Log Analytics workspace, Recovery Services Vault, Backup Vault) have been migrated into `JHG/app.main.bicep` and will be deployed into the same resource group you target for the application layer.

If you deploy the application to `eam-app-tst-ae-rg`, the operations resources will be created there as part of that deployment. To deploy only operations into a specific resource group (not recommended unless you change parameters), run the `app.main.bicep` template against the desired resource group.

Example: deploy app (includes operations)
```bash
# Ensure app resource group exists
az group create \
  --name eam-app-tst-ae-rg \
  --location australiaeast

# Deploy application + operations
az deployment group create \
  --resource-group eam-app-tst-ae-rg \
  --template-file JHG/app.main.bicep \
  --parameters JHG/infrastructure/environments/dev/main.dev.bicepparam \
  --parameters \
    masterSubnetId="$MASTER_SUBNET" \
    workerSubnetId="$WORKER_SUBNET" \
    dataSubnetId="$DATA_SUBNET" \
    pepSubnetId="$PEP_SUBNET" \
  --name "app-deploy-$(date +%Y%m%d-%H%M%S)"
```

---

## Step 5: Monitor Deployment Progress

### Via Azure CLI
```bash
# Watch deployment in real-time
az deployment sub show \
  --name "eam-aro-deploy-*" \
  --query "{State: properties.provisioningState, Status: properties.outputs}"

# Check specific resource group deployment
az deployment group show \
  --resource-group eam-app-tst-ae-rg \
  --name "app-deploy-*" \
  --query "{State: properties.provisioningState, Timestamp: properties.timestamp}"

# Get detailed errors if deployment fails
az deployment group show \
  --resource-group eam-app-tst-ae-rg \
  --name "app-deploy-*" \
  --query properties.error
```

### Via Azure Portal
1. Go to [Azure Portal](https://portal.azure.com)
2. Search for "Deployments"
3. Look for your deployment name (eam-aro-deploy-*)
4. Click to view deployment details
5. Monitor the status (Deploying → Succeeded or Failed)

---

## Step 6: Verify Deployment

### Check Resource Groups
```bash
# List all resource groups
az group list --query "[?contains(name, 'eam-')].{Name:name, Location:location, ProvisioningState:properties.state}" --output table
```

### Check ARO Cluster
```bash
# Get ARO cluster details
az aro show \
  --resource-group eam-app-tst-ae-rg \
  --name eam-app-tst-ae-aro \
  --query "{Name: name, Location: location, ProvisioningState: provisioningState, ApiServerUrl: apiserverProfile.url, IngressIp: ingressProfiles[0].ip}"

# Get ARO credentials
az aro list-credentials \
  --resource-group eam-app-tst-ae-rg \
  --name eam-app-tst-ae-aro

# Access ARO console
# Use the username and password from above in browser
# URL format: https://console-openshift-console.apps.<INGRESS_IP>.nip.io
```

### Check Networking
```bash
# List virtual networks
az network vnet list \
  --resource-group eam-net-tst-ae-rg \
  --output table

# List subnets
az network vnet subnet list \
  --resource-group eam-net-tst-ae-rg \
  --vnet-name eam-net-tst-ae-vnet \
  --output table

# List NSGs
az network nsg list \
  --resource-group eam-net-tst-ae-rg \
  --output table
```

### Check Storage Accounts
```bash
# List storage accounts
az storage account list \
  --resource-group eam-app-tst-ae-rg \
  --output table

# Get storage account keys
az storage account keys list \
  --resource-group eam-app-tst-ae-rg \
  --account-name eamdatadevaestfile
```

### Check Managed Identity
```bash
# Get managed identity details
az identity show \
  --resource-group eam-app-tst-ae-rg \
  --name eam-app-tst-ae-mi
```

---

## Step 7: Troubleshooting Common Issues

### Issue: Deployment Hangs (ARO takes too long)
**Expected Behavior**: ARO cluster deployment takes 30-45 minutes
**Solution**: Be patient! Check progress in Azure Portal

### Issue: Authentication Failed
```bash
# Check if you're logged in
az account show

# If not, login again
az login

# Clear cached credentials if needed
az logout
az login --use-device-code
```

### Issue: Insufficient Permissions
```bash
# Check your role
az role assignment list --scope /subscriptions/$(az account show --query id -o tsv) --output table

# You need: Owner or Contributor role at subscription level
```

### Issue: Quota Exceeded
```bash
# Check current usage
az vm usage list --location australiaeast --output table

# Common quota issues:
# - vCPU limits (ARO requires significant compute)
# - Public IP limits
# - Network interface limits
# Contact Azure support to increase quotas
```

### Issue: Parameter Validation Failed
```bash
# Validate parameter file syntax
bicep build JHG/infrastructure/main.bicep

# Check parameter types and defaults
az bicep build --file JHG/infrastructure/main.bicep --outfile template.json
```

### Issue: Network/Firewall Blocking Deployment
```bash
# If behind corporate firewall, ensure these IPs are allowed:
# - Azure ARM endpoints
# - Container registry endpoints (for ARO)
# - Microsoft Update servers
# Contact your network admin if needed
```

---

## Step 8: Post-Deployment Configuration

### 1. Connect to ARO Console
```bash
# Get cluster info
CLUSTER_RG="eam-app-tst-ae-rg"
CLUSTER_NAME="eam-app-tst-ae-aro"

# Get API server URL
API_URL=$(az aro show \
  --resource-group $CLUSTER_RG \
  --name $CLUSTER_NAME \
  --query apiserverProfile.url -o tsv)

# Get credentials
CREDENTIALS=$(az aro list-credentials \
  --resource-group $CLUSTER_RG \
  --name $CLUSTER_NAME)

echo "API Server URL: $API_URL"
echo "Credentials: $CREDENTIALS"

# Login via oc CLI (if installed)
oc login -u kubeadmin -p <password> $API_URL
```

### 2. Verify Storage Connectivity
```bash
# Test storage account access from ARO
# (This requires ARO pods with appropriate RBAC)
az storage account show-connection-string \
  --resource-group eam-app-tst-ae-rg \
  --name eamdatadevaestfile
```

### 3. Verify SQL MI Connectivity
```bash
# Get SQL MI endpoint
SQLMI_FQDN=$(az sql mi show \
  --resource-group eam-app-tst-ae-rg \
  --name eam-data-tst-ae-sqlmi-01 \
  --query fullyQualifiedDomainName -o tsv)

# Test connectivity (requires network connectivity)
# From ARO pod or jumphost:
# sqlcmd -S $SQLMI_FQDN -U sqladmin -P <password>
```

### 4. Configure Monitoring
```bash
# Get Log Analytics workspace
LA_WORKSPACE=$(az monitor log-analytics workspace list \
  --resource-group eam-app-tst-ae-rg \
  --query "[0].id" -o tsv)

# Enable ARO monitoring
# Configure in ARO console or via oc CLI
```

---

## Step 9: Cleanup (If Needed)

⚠️ **WARNING**: This will DELETE all resources!

```bash
# Delete all resource groups
az group delete \
  --name eam-net-tst-ae-rg \
  --yes --no-wait

az group delete \
  --name eam-app-tst-ae-rg \
  --yes --no-wait

az group delete \
  --name eam-app-tst-ae-rg \
  --yes --no-wait

# Monitor deletion progress
az group list --query "[?contains(name, 'eam-')].{Name:name, State:properties.state}"
```

---

## Deployment Timeline

| Component | Time | Status |
|-----------|------|--------|
| Resource Groups | < 1 min | Fast |
| VNet + Subnets | 2-5 min | Fast |
| NSGs | 1-2 min | Fast |
| Route Tables | 1-2 min | Fast |
| Managed Identity | < 1 min | Fast |
| Storage Accounts | 2-5 min | Fast |
| Application Insights | 1-2 min | Fast |
| **ARO Cluster** | **30-45 min** | ⏳ **SLOW** |
| SQL MI (optional) | **4-6 hours** | ⏳⏳ **VERY SLOW** |
| Private Endpoints | 5-10 min | Fast |
| Backup Vaults | 1-2 min | Fast |
| **Total (with ARO)** | **35-55 min** | - |
| **Total (with SQL MI)** | **4-7 hours** | - |

---

## Deployment Checklist

- [ ] Azure CLI authenticated
- [ ] Correct subscription selected
- [ ] Parameters reviewed and updated
- [ ] SQL MI password changed
- [ ] Resource group names verified
- [ ] Owner email updated in tags
- [ ] Key Vault exists (or will be created)
- [ ] Subscription has sufficient quota
- [ ] Network connectivity verified
- [ ] Firewall rules allow Azure endpoints
- [ ] Deployment initiated
- [ ] Monitoring in progress
- [ ] Deployment completed successfully
- [ ] Resource groups created
- [ ] ARO cluster accessible
- [ ] Storage accounts working
- [ ] SQL MI connectivity verified
- [ ] Monitoring configured

---

## Support & Troubleshooting

If deployment fails:

1. **Check Error Message**: Azure Portal → Deployments → Failed deployment → Error details
2. **Review Logs**: `az deployment group show --resource-group <RG> --name <DEPLOYMENT> --query properties.error`
3. **Validate Templates**: Run validation steps from Step 2
4. **Check Quotas**: Ensure subscription has enough quota for all resources
5. **Review NSG Rules**: Ensure NSG rules aren't blocking necessary traffic
6. **Contact Support**: Open Azure support ticket with deployment name and error

---

Generated: February 19, 2026
Last Updated: Current Session
