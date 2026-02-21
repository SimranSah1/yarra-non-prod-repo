using '../../main.bicep'

param environment = 'non-prod'
param location = 'australiaeast'

param tags = {
  owner: 'simran.sah@neudesic.com'
  environment: 'nonprod'
  project: 'EAM'
}

param vnetName = 'eam-net-tst-ae-vnet'
param vnetAddressPrefix = '10.90.32.0/19'
param dnsServers = ['10.0.10.15', '10.0.10.16', '10.100.10.10']

param masterSubnetName = 'eam-net-tst-ae-snet-aro-master'
param masterSubnetPrefix = '10.90.32.0/25'
param workerSubnetName = 'eam-net-tst-ae-snet-aro-worker'
param workerSubnetPrefix = '10.90.33.0/24'

param dataSubnetName = 'eam-net-tst-ae-snet-data'
param dataSubnetPrefix = '10.90.34.0/24'

param pepSubnetName = 'eam-net-tst-ae-snet-pep'
param pepSubnetPrefix = '10.90.35.0/24'

param jumpboxSubnetCidr = '10.90.36.0/24'

param routeTableName = 'eam-net-tst-ae-rt-spoke'
param hubFirewallIp = '10.0.1.4'

param masterNsgName = 'eam-net-tst-ae-nsg-aro-master'
param workerNsgName = 'eam-net-tst-ae-nsg-aro-worker'
param dataNsgName = 'eam-net-tst-ae-nsg-data'
param pepNsgName = 'eam-net-tst-ae-nsg-pep'

param networkingResourceGroupName = 'network-zones-tst-yt-rg'
param appResourceGroupName = 'eam-app-tst-ae-rg'

param managedIdentityName = 'eam-app-tst-ae-mi'

param keyVaultName = 'eam-sec-tst-ae-kv'
param keyVaultPepName = 'eam-sec-tst-ae-kv-pep'

param storageAccountFile = 'eamdatattaestfile'
param storageAccountInt = 'eamdatattaestint'

param sqlMiName = 'eam-data-tst-ae-sqlmi-01'
param deploySqlMi = true
param sqlMiAdminPassword = ''

param logAnalyticsWorkspaceName = 'eam-ops-tst-ae-log'
param appInsightsName = 'eam-mon-tst-ae-appi'
param logAnalyticsRetentionInDays = 30

param aroClusterName = 'eam-app-tst-ae-aro'
param aroClusterVersion = '4.14.0'
param aroDomain = 'tst.eam.neudesic.com'
param aroPullSecret = ''

param aroWorkerVmSize = 'Standard_D16s_v5'
param aroWorkerDiskSize = 128
param aroWorkerCount = 3

param aroApiVisibility = 'Private'
param aroIngressVisibility = 'Private'
param aroPodCidr = '10.128.0.0/14'
param aroServiceCidr = '172.30.0.0/16'

param enableDefender = true

param recoveryServicesVaultName = 'eam-ops-tst-ae-rsv'
param backupVaultName = 'eam-ops-tst-ae-bvault'

