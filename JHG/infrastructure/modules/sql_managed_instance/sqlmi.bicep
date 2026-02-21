@description('SQL Managed Instance name')
param sqlMiName string

@description('Location for resources')
param location string = resourceGroup().location

@description('Data subnet ID (must have SQL MI delegation)')
param subnetId string

@description('Administrator login name')
param administratorLogin string = 'sqladmin'

@description('Administrator password (passed from pipeline/CLI that fetches from Key Vault)')
@secure()
param administratorPassword string

@description('vCores for SQL MI')
@allowed([
  4
  8
  16
  24
  32
  40
  64
  80
])
param vCores int = 8

@description('Storage size in GB')
param storageSizeInGB int = 256

@description('SKU name')
@allowed([
  'GP_Gen5'
  'BC_Gen5'
])
param skuName string = 'GP_Gen5'

@description('License type')
@allowed([
  'BasePrice'
  'LicenseIncluded'
])
param licenseType string = 'LicenseIncluded'

@description('Collation')
param collation string = 'SQL_Latin1_General_CP1_CI_AS'

@description('Time zone')
param timezoneId string = 'UTC'

@description('Enable public data endpoint')
param publicDataEndpointEnabled bool = false

@description('Minimum TLS version')
@allowed([
  '1.0'
  '1.1'
  '1.2'
])
param minimalTlsVersion string = '1.2'

@description('Enable zone redundancy')
param zoneRedundant bool = false

@description('Tags to apply to resources')
param tags object = {}

resource sqlManagedInstance 'Microsoft.Sql/managedInstances@2023-05-01-preview' = {
  name: sqlMiName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: skuName
    tier: skuName == 'GP_Gen5' ? 'GeneralPurpose' : 'BusinessCritical'
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    subnetId: subnetId
    storageSizeInGB: storageSizeInGB
    vCores: vCores
    licenseType: licenseType
    collation: collation
    timezoneId: timezoneId
    publicDataEndpointEnabled: publicDataEndpointEnabled
    minimalTlsVersion: minimalTlsVersion
    zoneRedundant: zoneRedundant
  }
}

output sqlMiId string = sqlManagedInstance.id
output sqlMiName string = sqlManagedInstance.name
output sqlMiFqdn string = sqlManagedInstance.properties.fullyQualifiedDomainName
output sqlMiPrincipalId string = sqlManagedInstance.identity.principalId
