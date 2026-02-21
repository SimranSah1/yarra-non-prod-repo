@description('Backup Vault name')
param vaultName string

@description('Location for resources')
param location string = resourceGroup().location

@description('Tags to apply to resources')
param tags object = {}

resource backupVault 'Microsoft.DataProtection/backupVaults@2023-01-01' = {
  name: vaultName
  location: location
  tags: tags
  properties: {
    storageSettings: [
      {
        datastoreType: 'VaultStore'
        type: 'LocallyRedundant'
      }
    ]
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Backup Policy for Blob Storage (Operational backup - continuous)
resource blobBackupPolicy 'Microsoft.DataProtection/backupVaults/backupPolicies@2023-01-01' = {
  parent: backupVault
  name: 'BlobBackupPolicy'
  properties: {
    objectType: 'BackupPolicy'
    datasourceTypes: [
      'Microsoft.Storage/storageAccounts/blobServices'
    ]
    policyRules: [
      {
        name: 'Default'
        objectType: 'AzureRetentionRule'
        isDefault: true
        lifecycles: [
          {
            deleteAfter: {
              objectType: 'AbsoluteDeleteOption'
              duration: 'P30D'
            }
            sourceDataStore: {
              dataStoreType: 'OperationalStore'
              objectType: 'DataStoreInfoBase'
            }
          }
        ]
      }
    ]
  }
}

output vaultId string = backupVault.id
output vaultName string = backupVault.name
output backupPolicyId string = blobBackupPolicy.id
output vaultPrincipalId string = backupVault.identity.principalId
