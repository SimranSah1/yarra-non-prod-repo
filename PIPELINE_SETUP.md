# Pipeline Setup Guide

This guide walks you through setting up and running the Azure DevOps pipeline to deploy your Bicep infrastructure.

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Azure DevOps Setup](#azure-devops-setup)
3. [Key Vault Setup (for SQL MI Secret)](#key-vault-setup-for-sql-mi-secret)
4. [Running the Pipeline](#running-the-pipeline)
5. [Pipeline Stages Explained](#pipeline-stages-explained)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before you start, ensure you have:

1. **Azure Subscription** – active subscription where resource groups exist:
   - `network-zones-tst-yt-rg`
   - `eam-app-tst-ae-rg`

2. **Azure DevOps Organization & Project** – project where you'll host the pipeline

3. **Git Repository** – your code (including `JHG/`, `templates/`, `pipeline/` folders) must be pushed to your Azure DevOps repo

4. **Azure Key Vault** – existing Key Vault in your Azure subscription (e.g., `eam-sec-tst-ae-kv`) that will store the SQL MI admin password

---

## Azure DevOps Setup

### Step 1: Create a Service Connection

A Service Connection lets the pipeline authenticate to your Azure subscription.

1. In Azure DevOps, go to **Project Settings** (bottom left) → **Service connections**
2. Click **+ New service connection**
3. Choose **Azure Resource Manager**
4. Select **Service principal (automatic)** or **Service principal (manual)**
   - **Automatic** is easier; Azure DevOps creates the service principal for you
5. Fill in:
   - **Subscription**: Choose your Azure subscription
   - **Resource group**: Optional (leave blank)
6. Name it: `EAM-NonProd-SC` (this must match the `azureServiceConnection` variable in the pipeline)
7. Click **Save**

note- you SP might not have access at sub level -->Select subscription-->Open "Access control (IAM)"-->Add → Add role assignment -->Contributor, User, group or service principal --> select
### Step 2: Store SQL MI Password in Key Vault

The SQL MI admin password must be stored securely in your existing Key Vault.

1. In **Azure Portal**, navigate to your Key Vault: `eam-sec-tst-ae-kv`
2. Click **Secrets** (left sidebar)
3. Click **+ Generate/Import**
4. Name: `sqlMiAdminPassword`
5. Value: your secure password (e.g., `MySecureP@ss123!`)
6. Click **Create**

### Step 3: Grant Service Connection Access to Key Vault

The pipeline's service principal needs permission to read the Key Vault secret.

1. In your Key Vault (`eam-sec-tst-ae-kv`) → **Access policies** (left sidebar)
2. Click **+ Create**
3. Select template: **Secret Management**
4. Search for your service principal name (look in Azure DevOps Service Connection for the principal name)
5. Click **Next** → **Create**

---

## Key Vault Setup for SQL MI Secret

### Two Authentication Options

Your SQL MI module now supports **both** direct password and Key Vault secret retrieval:

#### Option A: Direct Password (Less Secure)
- Pass password directly in pipeline as parameter
- Password exposed in pipeline logs (not recommended for production)
- Set `sqlMiUseKeyVaultSecret = false` in parameters file

#### Option B: Key Vault Secret (Recommended for Production)
- Store password in Key Vault
- Password never appears in logs or pipeline variables
- Set `sqlMiUseKeyVaultSecret = true` in parameters file
- Bicep module fetches secret at deployment time using URI reference

### Setup Key Vault Secret

1. In **Azure Portal**, navigate to your Key Vault: `eam-sec-tst-ae-kv`
2. Click **Secrets** (left sidebar)
3. Click **+ Generate/Import**
4. Name: `sqlMiAdminPassword`
5. Value: your secure password (e.g., `MySecureP@ss123!`)
6. Click **Create**
7. **Copy the Secret URI** (you'll need this for the parameters file):
   - Format: `/subscriptions/{subscriptionId}/resourceGroups/{rgName}/providers/Microsoft.KeyVault/vaults/{vaultName}/secrets/sqlMiAdminPassword`

### Grant Service Connection Access to Key Vault

The pipeline's service principal needs permission to read the Key Vault secret.

1. In your Key Vault (`eam-sec-tst-ae-kv`) → **Access policies** (left sidebar)
2. Click **+ Create**
3. Select template: **Secret Management**
4. Search for your service principal name (look in Azure DevOps Service Connection for the principal name)
5. Click **Next** → **Create**

### Update Parameters File

Edit `JHG/infrastructure/environments/non-prod/main.non-prod.bicepparam`:

```bicep
param deploySqlMi = true  // Enable SQL MI deployment
param sqlMiUseKeyVaultSecret = true
param sqlMiAdminPassword = ''  // Leave empty when using Key Vault
param sqlMiKeyVaultSecretUri = '/subscriptions/{YOUR-SUBSCRIPTION-ID}/resourceGroups/eam-sec-tst-ae-rg/providers/Microsoft.KeyVault/vaults/eam-sec-tst-ae-kv/secrets/sqlMiAdminPassword'
```

Replace `{YOUR-SUBSCRIPTION-ID}` with your actual Azure subscription ID.

### Retrieve Secret in Pipeline

The pipeline template will fetch the SQL MI password from Key Vault at deployment time.

`templates/deploy-bicep.yml` already includes:

```yaml
steps:
  - task: AzureKeyVault@2
    displayName: 'Fetch secrets from Key Vault'
    inputs:
      azureSubscription: ${{ parameters.azureServiceConnection }}
      KeyVaultName: 'eam-sec-tst-ae-kv'
      SecretsFilter: 'sqlMiAdminPassword'
      RunnerDebugFlag: false

  - task: AzureCLI@2
    displayName: 'Deploy Bicep template (subscription)'
    inputs:
      azureSubscription: ${{ parameters.azureServiceConnection }}
      scriptType: bash
      scriptLocation: inlineScript
      inlineScript: |
        set -euo pipefail
        echo "Creating/updating resources at subscription scope"
        az deployment sub create \
          --location "${{ parameters.location }}" \
          --template-file "${{ parameters.bicepFile }}" \
          --parameters @"${{ parameters.parametersFile }}" \
          sqlMiAdminPassword="$(sqlMiAdminPassword)"
```

---

## Running the Pipeline

### Option 1: Push Code and Trigger Pipeline (Automatic)

1. Ensure all files are committed and pushed to your main branch:
   ```bash
   git add .
   git commit -m "Add Bicep infrastructure pipeline"
   git push origin main
   ```

2. Go to **Azure DevOps Project** → **Pipelines**
3. Click **+ New pipeline**
4. Select **Azure Repos Git** → select your repo
5. Choose **Existing Azure Pipelines YAML file**
6. Select: `pipeline/pipeline-non-prod.yml`
7. Click **Continue** → **Save and run**

The pipeline will trigger automatically on commits to `main` branch.

### Option 2: Manual Trigger

1. Go to **Pipelines** → select your pipeline
2. Click **Run pipeline** (top right)
3. Click **Run**

---

## Pipeline Stages Explained

Your pipeline has 4 stages (run sequentially):

### Stage 1: Preflight (Check Resource Groups)
- **What it does**: Verifies the three resource groups exist before proceeding
- **Fails if**: Any RG is missing
- **Duration**: ~30 seconds

### Stage 2: Validate (Syntax & Template Check)
- **What it does**: Builds your Bicep and validates the template without creating resources
- **Fails if**: Template has syntax errors or invalid parameters
- **Duration**: 1–2 minutes

### Stage 3: WhatIf (Preview Changes)
- **What it does**: Shows what resources will be created/updated/deleted (like a dry-run)
- **Does NOT create anything** – just shows preview
- **Fails if**: Template would fail during deployment
- **Duration**: 2–5 minutes
- **Review the output**: Check if the changes look correct

### Stage 4: Deploy (Create/Update Resources)
- **What it does**: Actually creates or updates resources in Azure
- **RUNS ONLY IF YOU APPROVE** (requires manual approval)
- **Duration**: 30 minutes to several hours (depends on ARO, SQL MI, etc.)

---

## Troubleshooting

### Problem: "Service connection not found"
- **Cause**: Service connection name doesn't match `EAM-NonProd-SC` in pipeline
- **Fix**: Update `azureServiceConnection` in `pipeline/pipeline-non-prod.yml` to match your actual service connection name

### Problem: "Resource group not found"
- **Cause**: One of the three RGs doesn't exist in Azure
- **Fix**: Create missing RGs in Azure Portal or via Azure CLI:
  ```bash
   # Resource groups are expected to already exist for this pipeline:
   # - network-zones-tst-yt-rg
   # - eam-app-tst-ae-rg
  ```

### Problem: "Unauthorized: principal does not have access to Key Vault"
- **Cause**: Service principal needs permission on Key Vault
- **Fix**: Add Access Policy to Key Vault (see Step 3 in [Azure DevOps Setup](#step-3-grant-service-connection-access-to-key-vault))

### Problem: "Invalid template or parameters"
- **Cause**: Bicep template has errors or parameter file is missing required values
- **Fix**: 
  1. Run local validation:
     ```bash
     az bicep build --file JHG/infrastructure/main.bicep
     az deployment sub validate --location australiaeast --template-file JHG/infrastructure/main.bicep --parameters @JHG/infrastructure/environments/non-prod/main.non-prod.bicepparam
     ```
  2. Check `bicep build` output for errors

### Problem: "Incomplete parameter values"
- **Cause**: `aroPullSecret` or other required param is empty
- **Fix**: Update `JHG/infrastructure/environments/non-prod/main.non-prod.bicepparam` with actual values

---

## Quick Reference: Variable Mapping

| Pipeline Variable | Value | Where Used |
|---|---|---|
| `azureServiceConnection` | `EAM-NonProd-SC` | All stages (authenticate to Azure) |
| `resourceGroup` | `network-zones-tst-yt-rg` | Preflight check |
| `appResourceGroup` | `eam-app-tst-ae-rg` | Preflight check |
| `location` | `australiaeast` | Bicep deployment location |
| `bicepFile` | `JHG/infrastructure/main.bicep` | Template being deployed |
| `parametersFile` | `JHG/infrastructure/environments/non-prod/main.non-prod.bicepparam` | Parameters for template |

---

## Next Steps

1. ✅ Create the **Service Connection** (Step 1 above)
2. ✅ Store SQL MI password in **Key Vault** (Step 2 above)
3. ✅ Push code to **Git repository**
4. ✅ Create **Pipeline** in Azure DevOps
5. ✅ **Run the pipeline** and review What-If output
6. ✅ Approve the **Deploy stage** to create resources

---

## Need Help?

- Check pipeline logs: **Pipelines** → select your pipeline → select run → view logs
- Validate locally before pushing: use the Azure CLI commands in Troubleshooting section
