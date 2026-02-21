// Deploy Application Resources with ARO (Azure Red Hat OpenShift)
targetScope = 'resourceGroup'

param environment string = 'non-prod'
param location string = 'australiaeast'

// Sanitize environment name for deployment names (replace spaces with hyphens)
var envSanitized = replace(environment, ' ', '-')
param tags object = {
  owner: 'simran.sah@neudesic.com'
  environment: 'nonprod'
  project: 'EAM'
}

// ========================================
// ARO CLUSTER PARAMETERS
// ========================================

@description('ARO Cluster name')
param aroClusterName string = 'eam-app-tst-ae-aro'

@description('ARO cluster version')
param aroClusterVersion string = '4.14.0'

@description('ARO domain')
param aroDomain string = ''

@secure()
@description('ARO pull secret')
param aroPullSecret string = ''

// aro client id/secret removed (not required)

@description('ARO worker VM size')
param aroWorkerVmSize string = 'Standard_D4s_v3'

@description('ARO worker disk size')
param aroWorkerDiskSize int = 128

@description('ARO worker node count')
param aroWorkerCount int = 3

@description('ARO API server visibility')
param aroApiVisibility string = 'Public'

@description('ARO ingress visibility')
param aroIngressVisibility string = 'Private'

@description('ARO pod CIDR')
param aroPodCidr string = '10.128.0.0/14'

@description('ARO service CIDR')
param aroServiceCidr string = '172.30.0.0/16'

@description('Master subnet ID')
param masterSubnetId string

@description('Worker subnet ID')
param workerSubnetId string

@description('Protected subnet CIDR for other resources')
param dataSubnetId string

@description('Private endpoint subnet ID')
param pepSubnetId string

// Managed Identity
param managedIdentityName string = 'eam-app-tst-ae-mi'

// Storage Accounts
param storageAccountFile string = 'eamdatattaestfile'
param storageAccountInt string = 'eamdatattaestint'

// Application Insights and Monitoring
param appInsightsName string = 'eam-mon-tst-ae-appi'

// Log Analytics (operations)
param logAnalyticsWorkspaceName string = 'eam-ops-tst-ae-log'
param logRetentionInDays int = 30
// SQL Managed Instance
param sqlMiName string = 'eam-data-tst-ae-sqlmi-01'
param deploySqlMi bool = false

@secure()
param sqlMiAdminPassword string = ''

// RBAC Role Assignments (set to false if service principal lacks permissions)
param deployRoleAssignments bool = true

// Key Vault (existing - manually created in Azure Portal)
param keyVaultName string
param keyVaultResourceGroup string = 'eam-sec-tst-ae-rg'
param keyVaultPepName string = 'eam-sec-tst-ae-kv-pep'

// Recovery Services and Backup Vaults
param recoveryServicesVaultName string = 'eam-bkp-tst-ae-rsv'
param backupVaultName string = 'eam-bkp-tst-ae-bvault'

// Reference existing Key Vault
resource existingKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
  scope: resourceGroup(keyVaultResourceGroup)
}

// ========================================
// 1. MANAGED IDENTITY
// ========================================

module managedIdentity 'infrastructure/modules/identity/managedidentity.bicep' = {
  name: 'deploy-mi-${envSanitized}'
  params: {
    managedIdentityName: managedIdentityName
    location: location
    tags: tags
  }
}

// ========================================
// 2. AZURE RED HAT OPENSHIFT (ARO) CLUSTER
// ========================================

module aroCluster 'infrastructure/modules/aro/aro.bicep' = {
  name: 'deploy-aro-${envSanitized}'
  params: {
    clusterName: aroClusterName
    location: location
    masterSubnetId: masterSubnetId
    workerSubnetId: workerSubnetId
    clusterVersion: aroClusterVersion
    aroDomain: aroDomain
    podCidr: aroPodCidr
    serviceCidr: aroServiceCidr
    outboundType: 'Loadbalancer'
    pullSecret: aroPullSecret
    workerVmSize: aroWorkerVmSize
    workerDiskSize: aroWorkerDiskSize
    workerCount: aroWorkerCount
    apiVisibility: aroApiVisibility
    ingressVisibility: aroIngressVisibility
    tags: tags
  }
}

// ========================================
// 3. STORAGE ACCOUNTS (2 for data)
// ========================================

module storageFile 'infrastructure/modules/storage_account/storageaccount.bicep' = {
  name: 'deploy-storage-file-${envSanitized}'
  params: {
    storageAccountName: storageAccountFile
    location: location
    tags: tags
    skuName: 'Standard_LRS'
    accessTier: 'Hot'
    networkAclsDefaultAction: 'Allow'
    allowSharedKeyAccess: false
    logAnalyticsWorkspaceId: ''
  }
}

module storageInt 'infrastructure/modules/storage_account/storageaccount.bicep' = {
  name: 'deploy-storage-int-${envSanitized}'
  params: {
    storageAccountName: storageAccountInt
    location: location
    tags: tags
    skuName: 'Standard_LRS'
    accessTier: 'Hot'
    networkAclsDefaultAction: 'Allow'
    allowSharedKeyAccess: false
    logAnalyticsWorkspaceId: ''
  }
}

// ========================================
// 4. RBAC ROLE ASSIGNMENTS FOR MANAGED IDENTITY
// ========================================

// Storage Blob Data Contributor on Storage File
resource roleAssignmentStorageFile 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployRoleAssignments) {
  name: guid(storageAccountFile, managedIdentityName, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    )
    principalId: managedIdentity.outputs.managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    storageFile
  ]
}

// Storage Blob Data Contributor on Storage Int
resource roleAssignmentStorageInt 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployRoleAssignments) {
  name: guid(storageAccountInt, managedIdentityName, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    )
    principalId: managedIdentity.outputs.managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    storageInt
  ]
}

// ========================================
// 5. APPLICATION INSIGHTS
// ========================================

module appInsights 'infrastructure/modules/monitoring/application_insights.bicep' = {
  name: 'deploy-appinsights-${envSanitized}'
  params: {
    appInsightsName: appInsightsName
    location: location
    tags: tags
    workspaceResourceId: ''
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Disabled'
  }
}

// ========================================
// OPERATIONS RESOURCES (migrated from ops.main.bicep)
// These were moved into app.main.bicep per request — they will be created in the app resource group
// ========================================

module logAnalytics 'infrastructure/modules/monitoring/loganalytics.bicep' = {
  name: 'deploy-log-${envSanitized}'
  params: {
    workspaceName: logAnalyticsWorkspaceName
    location: location
    retentionInDays: logRetentionInDays
    sku: 'PerGB2018'
    tags: tags
  }
}

module recoveryVault 'infrastructure/modules/backup/recoveryservicesvault.bicep' = {
  name: 'deploy-rsv-${envSanitized}'
  params: {
    vaultName: recoveryServicesVaultName
    location: location
    tags: tags
  }
}

module backupVault 'infrastructure/modules/backup/backupvault.bicep' = {
  name: 'deploy-bvault-${envSanitized}'
  params: {
    vaultName: backupVaultName
    location: location
    tags: tags
  }
}

// ========================================
// 6. SQL MANAGED INSTANCE (Optional - takes 4-6 hours)
// ========================================
// Note: SQL MI credentials should be manually stored in Key Vault: eam-sec-tst-ae-kv

module sqlMi 'infrastructure/modules/sql_managed_instance/sqlmi.bicep' = if (deploySqlMi) {
  name: 'deploy-sqlmi-${envSanitized}'
  params: {
    sqlMiName: sqlMiName
    location: location
    subnetId: dataSubnetId
    administratorLogin: 'sqladmin'
    administratorPassword: sqlMiAdminPassword
    vCores: 8
    storageSizeInGB: 256
    skuName: 'GP_Gen5'
    publicDataEndpointEnabled: false
    minimalTlsVersion: '1.2'
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    timezoneId: 'UTC'
    zoneRedundant: false
    tags: tags
  }
}

// ========================================
// 7. PRIVATE ENDPOINTS (2 for storage + optional SQL MI)
// ========================================

// Storage File - Blob Private Endpoint
module peStorageFileBlob 'infrastructure/modules/networking/private_endpoint/private_endpoint.bicep' = {
  name: 'deploy-pe-stfile-blob-${envSanitized}'
  params: {
    privateEndpointName: '${storageAccountFile}-pep-blob'
    location: location
    tags: tags
    privateLinkServiceId: storageFile.outputs.storageAccountId
    groupIds: ['blob']
    subnetId: pepSubnetId
    privateDnsZoneIds: []
  }
}

// Storage File - File Private Endpoint
module peStorageFileFile 'infrastructure/modules/networking/private_endpoint/private_endpoint.bicep' = {
  name: 'deploy-pe-stfile-file-${envSanitized}'
  params: {
    privateEndpointName: '${storageAccountFile}-pep-file'
    location: location
    tags: tags
    privateLinkServiceId: storageFile.outputs.storageAccountId
    groupIds: ['file']
    subnetId: pepSubnetId
    privateDnsZoneIds: []
  }
}

// Storage Int - Blob Private Endpoint
module peStorageIntBlob 'infrastructure/modules/networking/private_endpoint/private_endpoint.bicep' = {
  name: 'deploy-pe-stint-blob-${envSanitized}'
  params: {
    privateEndpointName: '${storageAccountInt}-pep-blob'
    location: location
    tags: tags
    privateLinkServiceId: storageInt.outputs.storageAccountId
    groupIds: ['blob']
    subnetId: pepSubnetId
    privateDnsZoneIds: []
  }
}

// Key Vault - Private Endpoint
module peKeyVault 'infrastructure/modules/networking/private_endpoint/private_endpoint.bicep' = {
  name: 'deploy-pe-keyvault-${envSanitized}'
  params: {
    privateEndpointName: keyVaultPepName
    location: location
    tags: tags
    privateLinkServiceId: existingKeyVault.id
    groupIds: ['vault']
    subnetId: pepSubnetId
    privateDnsZoneIds: []
  }
}

// SQL MI Private Endpoint (only if SQL MI is deployed)
resource sqlMiPep 'Microsoft.Network/privateEndpoints@2023-05-01' = if (deploySqlMi) {
  name: '${sqlMiName}-pep'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: pepSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${sqlMiName}-pep-connection'
        properties: {
          privateLinkServiceId: resourceId('Microsoft.Sql/managedInstances', sqlMiName)
          groupIds: ['managedInstance']
        }
      }
    ]
  }
  dependsOn: [
    sqlMi
  ]
}

// ========================================
// 8. DEFENDER FOR SERVERS
// ========================================

// module defender 'infrastructure/modules/security/defender.bicep' = {
//   name: 'deploy-defender-${envSanitized}'
//   params: {
//     enableDefender: enableDefender
//     serverPlan: serverPlan
//   }
// }
// ========================================
// OUTPUTS
// ========================================

output managedIdentityId string = managedIdentity.outputs.managedIdentityId
output managedIdentityPrincipalId string = managedIdentity.outputs.managedIdentityPrincipalId
output aroClusterId string = aroCluster.outputs.clusterId
output aroClusterName string = aroCluster.outputs.clusterName
output aroApiServerUrl string = aroCluster.outputs.apiServerUrl
output aroIngressIp string = aroCluster.outputs.ingressIp
output aroConsoleUrl string = aroCluster.outputs.consoleUrl
output storageFileId string = storageFile.outputs.storageAccountId
output storageIntId string = storageInt.outputs.storageAccountId
output appInsightsId string = appInsights.outputs.applicationInsightsId
output keyVaultId string = existingKeyVault.id
output keyVaultName string = existingKeyVault.name
//output defenderEnabled bool = defender.outputs.defenderEnabled
output logAnalyticsWorkspaceId string = logAnalytics.outputs.workspaceId
output logAnalyticsWorkspaceName string = logAnalytics.outputs.workspaceName
output recoveryServicesVaultId string = recoveryVault.outputs.vaultId
output recoveryServicesVaultName string = recoveryVault.outputs.vaultName
output backupVaultId string = backupVault.outputs.vaultId
output backupVaultName string = backupVault.outputs.vaultName
