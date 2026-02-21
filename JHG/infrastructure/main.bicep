// Main orchestration file for EAM infrastructure with ARO
targetScope = 'subscription'

param environment string = 'non-prod'
param location string = 'australiaeast'

param tags object = {
  owner: 'simran.sah@neudesic.com'
  environment: 'non-prod'
  project: 'EAM'
}

// ========================================
// NETWORK CONFIGURATION
// ========================================

param vnetName string = 'eam-net-tst-ae-vnet'
param vnetAddressPrefix string = '10.90.32.0/19'
param dnsServers array = ['10.0.10.15', '10.0.10.16', '10.100.10.10']

param masterSubnetName string = 'eam-net-tst-ae-snet-aro-master'
param masterSubnetPrefix string = '10.90.32.0/25'

param workerSubnetName string = 'eam-net-tst-ae-snet-aro-worker'
param workerSubnetPrefix string = '10.90.33.0/24'

param dataSubnetName string = 'eam-net-tst-ae-snet-data'
param dataSubnetPrefix string = '10.90.34.0/24'

param pepSubnetName string = 'eam-net-tst-ae-snet-pep'
param pepSubnetPrefix string = '10.90.35.0/24'

param routeTableName string = 'eam-net-tst-ae-rt-spoke'
param hubFirewallIp string = '10.0.1.4'

param masterNsgName string = 'eam-net-tst-ae-nsg-aro-master'
param workerNsgName string = 'eam-net-tst-ae-nsg-aro-worker'
param dataNsgName string = 'eam-net-tst-ae-nsg-data'
param pepNsgName string = 'eam-net-tst-ae-nsg-pep'
// Needed for NSG rules
param jumpboxSubnetCidr string = '10.90.36.0/24'

// ========================================
// SECURITY / STORAGE
// ========================================

param keyVaultName string = 'eam-sec-tst-ae-kv'
param keyVaultPepName string = 'eam-sec-tst-ae-kv-pep'
param keyVaultResourceGroupName string = 'eam-sec-tst-ae-rg'
param managedIdentityName string = 'eam-app-tst-ae-mi'
param storageAccountFile string = 'eamdatattaestfile'
param storageAccountInt string = 'eamdatattaestint'

// ========================================
// ARO CONFIGURATION
// ========================================

param aroClusterName string = 'eam-app-tst-ae-aro'
param aroClusterVersion string = '4.14.0'
param aroDomain string = ''

@secure()
param aroPullSecret string = ''

// removed aro client id/secret parameters (not used)


param aroWorkerVmSize string = 'Standard_D16s_v5 '
param aroWorkerDiskSize int = 128
param aroWorkerCount int = 3
param aroApiVisibility string = 'Private'
param aroIngressVisibility string = 'Private'
param aroPodCidr string = '10.128.0.0/14'
param aroServiceCidr string = '172.30.0.0/16'

// ========================================
// DEFENDER (SUBSCRIPTION LEVEL)
// ========================================

param enableDefender bool = true

// ========================================
// SQL MI
// ========================================

param sqlMiName string = 'eam-data-tst-ae-sqlmi-01'
param deploySqlMi bool = false

@secure()
param sqlMiAdminPassword string = ''

// ========================================
// MONITORING
// ========================================

param appInsightsName string = 'eam-mon-tst-ae-appi'
param logAnalyticsWorkspaceName string = 'eam-mon-tst-ae-log'
param logAnalyticsRetentionInDays int = 30

// ========================================
// RESOURCE GROUPS
// ========================================

param networkingResourceGroupName string = 'network-zones-tst-yt-rg'
param appResourceGroupName string = 'eam-app-tst-ae-rg'

param recoveryServicesVaultName string = 'eam-ops-tst-ae-rsv'
param backupVaultName string = 'eam-ops-tst-ae-bvault'

// NOTE: Resource groups are created manually inthe portal.
// Modules below target the existing resource groups by name.

// ========================================
// 2️⃣ NETWORKING MODULE
// ========================================

module networkingDeployment '../networking.main.bicep' = {
  name: 'deploy-networking'
  scope: resourceGroup(networkingResourceGroupName)
  params: {
    environment: environment
    location: location
    tags: tags
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    dnsServers: dnsServers
    masterSubnetName: masterSubnetName
    masterSubnetPrefix: masterSubnetPrefix
    workerSubnetName: workerSubnetName
    workerSubnetPrefix: workerSubnetPrefix
    dataSubnetName: dataSubnetName
    dataSubnetPrefix: dataSubnetPrefix
    pepSubnetName: pepSubnetName
    pepSubnetPrefix: pepSubnetPrefix
    routeTableName: routeTableName
    hubFirewallIp: hubFirewallIp
    masterNsgName: masterNsgName
    workerNsgName: workerNsgName
    dataNsgName: dataNsgName
    pepNsgName: pepNsgName
    jumpboxSubnetCidr: jumpboxSubnetCidr

  }
}

// ========================================
// 3️⃣ APPLICATION (ARO) MODULE
// ========================================

module appDeployment '../app.main.bicep' = {
  name: 'deploy-app'
  scope: resourceGroup(appResourceGroupName)
  params: {
    environment: environment
    location: location
    tags: tags
    aroClusterName: aroClusterName
    aroClusterVersion: aroClusterVersion
    aroDomain: aroDomain
    aroPullSecret: aroPullSecret
    aroWorkerVmSize: aroWorkerVmSize
    aroWorkerDiskSize: aroWorkerDiskSize
    aroWorkerCount: aroWorkerCount
    aroApiVisibility: aroApiVisibility
    aroIngressVisibility: aroIngressVisibility
    aroPodCidr: aroPodCidr
    aroServiceCidr: aroServiceCidr
    masterSubnetId: networkingDeployment.outputs.masterSubnetId
    workerSubnetId: networkingDeployment.outputs.workerSubnetId
    dataSubnetId: networkingDeployment.outputs.dataSubnetId
    pepSubnetId: networkingDeployment.outputs.pepSubnetId
    managedIdentityName: managedIdentityName
    storageAccountFile: storageAccountFile
    storageAccountInt: storageAccountInt
    appInsightsName: appInsightsName
    sqlMiName: sqlMiName
    deploySqlMi: deploySqlMi
    sqlMiAdminPassword: sqlMiAdminPassword
    keyVaultName: keyVaultName
    keyVaultPepName: keyVaultPepName
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logRetentionInDays: logAnalyticsRetentionInDays
    backupVaultName: backupVaultName
    recoveryServicesVaultName: recoveryServicesVaultName  
  }
}

// Note: operations resources (log analytics, recovery vault, backup vault) were migrated into `app.main.bicep` and will deploy into the application resource group.

// ========================================
// 5️⃣ DEFENDER MODULE (SUBSCRIPTION SCOPE)
// ========================================

module defender 'modules/security/defender.bicep' = {
  name: 'deploy-defender-${environment}'
  scope: subscription()
  params: {
    enableDefender: enableDefender
  }
}

// ========================================
// OUTPUTS
// ========================================

output networkingResourceGroupName string = networkingResourceGroupName
output appResourceGroupName string = appResourceGroupName

output aroClusterId string = appDeployment.outputs.aroClusterId
output aroClusterName string = appDeployment.outputs.aroClusterName
output aroApiServerUrl string = appDeployment.outputs.aroApiServerUrl
output aroIngressIp string = appDeployment.outputs.aroIngressIp
output aroConsoleUrl string = appDeployment.outputs.aroConsoleUrl

output vnetId string = networkingDeployment.outputs.vnetId
output masterSubnetId string = networkingDeployment.outputs.masterSubnetId
output workerSubnetId string = networkingDeployment.outputs.workerSubnetId

output defenderEnabled bool = defender.outputs.defenderEnabled
