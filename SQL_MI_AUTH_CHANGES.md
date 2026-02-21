# SQL MI Authentication Changes – Direct Password vs Key Vault

## Summary

The SQL MI module has been updated to support **both** authentication methods:
1. **Direct Password** – accepts password as parameter (less secure)
2. **Key Vault Secret** – retrieves password from Key Vault at deployment time (recommended for production)

---

## Files Changed

### 1. **JHG/infrastructure/modules/sql_managed_instance/sqlmi.bicep**
   - Added: `keyVaultSecretUri` parameter
   - Added: `useKeyVaultSecret` switch parameter
   - Added: Logic to use Key Vault secret if enabled, fallback to direct password
   
   **Key changes:**
   ```bicep
   param administratorLogin string = 'sqladmin'
   
   @secure()
   param administratorPassword string = ''  // Optional: direct password
   
   param keyVaultSecretUri string = ''  // Optional: Key Vault secret URI
   param useKeyVaultSecret bool = false  // Toggle between password sources
   
   // Determines which password source to use
   var finalPassword = useKeyVaultSecret ? reference(keyVaultSecretUri, '2023-07-01').value : administratorPassword
   ```

### 2. **JHG/app.main.bicep**
   - Added: `sqlMiUseKeyVaultSecret` parameter
   - Added: `sqlMiKeyVaultSecretUri` parameter
   - Updated: SQL MI module call to pass both parameters
   
   **Key changes:**
   ```bicep
   param sqlMiUseKeyVaultSecret bool = true
   param sqlMiKeyVaultSecretUri string = ''
   param sqlMiAdminPassword string = ''  // Now optional
   
   module sqlMi 'infrastructure/modules/sql_managed_instance/sqlmi.bicep' = if (deploySqlMi) {
     params: {
       useKeyVaultSecret: sqlMiUseKeyVaultSecret
       keyVaultSecretUri: sqlMiKeyVaultSecretUri
       administratorPassword: sqlMiAdminPassword
       // ... other params
     }
   }
   ```

### 3. **JHG/infrastructure/main.bicep**
   - Added: `deploySqlMi` parameter (was missing)
   - Added: `sqlMiUseKeyVaultSecret` parameter
   - Added: `sqlMiKeyVaultSecretUri` parameter
   - Updated: App module call to pass these parameters
   
   **Key changes:**
   ```bicep
   param deploySqlMi bool = false
   param sqlMiUseKeyVaultSecret bool = true
   param sqlMiKeyVaultSecretUri string = ''
   
   module appDeployment '../app.main.bicep' = {
     params: {
       deploySqlMi: deploySqlMi
       sqlMiUseKeyVaultSecret: sqlMiUseKeyVaultSecret
       sqlMiKeyVaultSecretUri: sqlMiKeyVaultSecretUri
       // ... other params
     }
   }
   ```

### 4. **JHG/infrastructure/environments/non-prod/main.non-prod.bicepparam**
   - Added: `deploySqlMi` parameter
   - Added: `sqlMiUseKeyVaultSecret` parameter
   - Added: `sqlMiKeyVaultSecretUri` parameter
   - Updated: Removed hardcoded SQL MI password (leave empty when using Key Vault)
   
   **Key changes:**
   ```bicep
   param deploySqlMi = false
   param sqlMiUseKeyVaultSecret = true
   param sqlMiAdminPassword = ''  // Leave empty when using Key Vault
   param sqlMiKeyVaultSecretUri = '/subscriptions/{subscriptionId}/resourceGroups/eam-sec-tst-ae-rg/providers/Microsoft.KeyVault/vaults/eam-sec-tst-ae-kv/secrets/sqlMiAdminPassword'
   ```

### 5. **templates/deploy-bicep.yml**
   - Already includes: `AzureKeyVault@2` task to fetch secret
   - Already passes: `sqlMiAdminPassword` variable to deployment
   
   No changes needed – already supports Key Vault integration!

### 6. **PIPELINE_SETUP.md**
   - Updated: New "Two Authentication Options" section
   - Added: Setup instructions for Key Vault secret
   - Added: URI format example
   - Added: Parameters file update example

---

## Usage Guide

### Option A: Direct Password (Less Secure)

```bicep
// In non-prod.bicepparam
param deploySqlMi = true
param sqlMiUseKeyVaultSecret = false
param sqlMiAdminPassword = 'MyPassword123!'
param sqlMiKeyVaultSecretUri = ''
```

**⚠️ Warning:** Password will appear in pipeline logs and deployment history!

---

### Option B: Key Vault Secret (Recommended)

#### Step 1: Store Password in Key Vault
```bash
az keyvault secret set \
  --vault-name eam-sec-tst-ae-kv \
  --name sqlMiAdminPassword \
  --value "MySecurePassword123!"
```

#### Step 2: Get Secret URI
```bash
az keyvault secret show \
  --vault-name eam-sec-tst-ae-kv \
  --name sqlMiAdminPassword \
  --query id \
  --output tsv
```

Output example:
```
/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/eam-sec-tst-ae-rg/providers/Microsoft.KeyVault/vaults/eam-sec-tst-ae-kv/secrets/sqlMiAdminPassword/abc123def456
```

#### Step 3: Update Parameters File
```bicep
// In non-prod.bicepparam
param deploySqlMi = true
param sqlMiUseKeyVaultSecret = true
param sqlMiAdminPassword = ''  // Leave empty
param sqlMiKeyVaultSecretUri = '/subscriptions/{YOUR-SUB-ID}/resourceGroups/eam-sec-tst-ae-rg/providers/Microsoft.KeyVault/vaults/eam-sec-tst-ae-kv/secrets/sqlMiAdminPassword'
```

---

## How It Works

### Direct Password Flow
1. Password passed in parameters file → bicep deploy → SQL MI

### Key Vault Secret Flow
1. Pipeline fetches secret from Key Vault → stored as `$(sqlMiAdminPassword)` variable
2. Variable passed to `az deployment` command as `sqlMiAdminPassword` parameter
3. Bicep receives parameter
4. Bicep detects `useKeyVaultSecret = true`
5. Bicep calls `reference()` to fetch secret from Key Vault URI
6. Bicep uses fetched secret for SQL MI creation

---

## Security Best Practices

✅ **Recommended:**
- Use **Key Vault Secret** option for production
- Pipeline secret never stored in logs
- Secret retrieved at deployment time only
- Service principal needs minimal permissions (read secret only)

❌ **Avoid in Production:**
- Direct password option exposes secrets in logs
- Password visible in deployment history
- Password in version control

---

## Troubleshooting

### Error: "Could not get key vault secret"
- **Cause**: Key Vault URI is incorrect or secret doesn't exist
- **Fix**: Verify URI format and secret name match exactly

### Error: "Principal not authorized to get secret"
- **Cause**: Service principal lacks Key Vault access
- **Fix**: Add "Secret read" permission to service principal in Key Vault Access Policies

### Error: "Invalid secret reference"
- **Cause**: Bicep can't parse the Key Vault URI
- **Fix**: Ensure `keyVaultSecretUri` includes full path including `/secrets/{secretName}`

---

## Testing Locally

To test before pipeline run:

```bash
# Set parameters
export VAULT_URI="/subscriptions/{SUB-ID}/resourceGroups/.../secrets/sqlMiAdminPassword"

# Option 1: Direct password
az deployment sub validate \
  --location australiaeast \
  --template-file JHG/infrastructure/main.bicep \
  --parameters @JHG/infrastructure/environments/non-prod/main.non-prod.bicepparam \
  sqlMiUseKeyVaultSecret=false \
  sqlMiAdminPassword="MyPassword123!"

# Option 2: Key Vault Secret
az deployment sub validate \
  --location australiaeast \
  --template-file JHG/infrastructure/main.bicep \
  --parameters @JHG/infrastructure/environments/non-prod/main.non-prod.bicepparam \
  sqlMiUseKeyVaultSecret=true \
  sqlMiKeyVaultSecretUri="$VAULT_URI"
```
