@description('Name of the Application Insights resource')
param appInsightsName string

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Application type')
@allowed([
  'web'
  'other'
])
param applicationType string = 'web'

@description('Resource ID of the Log Analytics workspace')
param workspaceResourceId string = ''

@description('Retention in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 90

// removed: daily data cap param not used

@description('Disable IP masking')
param disableIpMasking bool = false

@description('Tags to apply to the resources')
param tags object = {}

@description('Public network access for ingestion')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccessForIngestion string = 'Disabled'

@description('Public network access for query')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccessForQuery string = 'Disabled'

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: applicationType
    WorkspaceResourceId: !empty(workspaceResourceId) ? workspaceResourceId : null
    RetentionInDays: retentionInDays
    publicNetworkAccessForIngestion: publicNetworkAccessForIngestion
    publicNetworkAccessForQuery: publicNetworkAccessForQuery
    DisableIpMasking: disableIpMasking
  }
}

output applicationInsightsId string = applicationInsights.id
output applicationInsightsName string = applicationInsights.name
output instrumentationKey string = applicationInsights.properties.InstrumentationKey
output connectionString string = applicationInsights.properties.ConnectionString
