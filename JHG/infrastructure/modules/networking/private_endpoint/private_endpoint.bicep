@description('The name of the private endpoint to be created.')
param privateEndpointName string

@description('The location of the resources')
param location string = resourceGroup().location

@description('The resource ID of the resource to create private endpoint for (e.g., Key Vault)')
param privateLinkServiceId string

@description('The subresource to connect to (e.g., vault for Key Vault)')
param groupIds array = [
  'vault'
]

@description('The resource ID of the subnet where private endpoint will be created')
param subnetId string

@description('The name of the private DNS zone group')
param privateDnsZoneGroupName string = 'default'

@description('The resource IDs of the private DNS zones')
param privateDnsZoneIds array = []

@description('Tags to apply to the resources')
param tags object = {}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: privateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: privateLinkServiceId
          groupIds: groupIds
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = if (length(privateDnsZoneIds) > 0) {
  parent: privateEndpoint
  name: privateDnsZoneGroupName
  properties: {
    privateDnsZoneConfigs: [
      for (zoneId, i) in privateDnsZoneIds: {
        name: 'config${i + 1}'
        properties: {
          privateDnsZoneId: zoneId
        }
      }
    ]
  }
}

output privateEndpointId string = privateEndpoint.id
output privateEndpointName string = privateEndpoint.name
