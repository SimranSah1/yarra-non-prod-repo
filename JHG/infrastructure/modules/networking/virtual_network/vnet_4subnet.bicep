@description('Virtual Network name')
param virtualNetworkName string

@description('Location for resources')
param location string = resourceGroup().location

@description('VNet address prefix')
param addressPrefix string

@description('Master subnet name for ARO')
param masterSubnetName string

@description('Master subnet prefix for ARO')
param masterSubnetPrefix string

@description('Worker subnet name for ARO')
param workerSubnetName string

@description('Worker subnet prefix for ARO')
param workerSubnetPrefix string

@description('Data subnet name')
param dataSubnetName string

@description('Data subnet prefix')
param dataSubnetPrefix string

@description('Private Endpoint subnet name')
param pepSubnetName string

@description('Private Endpoint subnet prefix')
param pepSubnetPrefix string

@description('Custom DNS servers')
param dnsServers array = []

@description('Master NSG ID')
param masterNsgId string = ''

@description('Worker NSG ID')
param workerNsgId string = ''

@description('Data NSG ID')
param dataNsgId string = ''

@description('PEP NSG ID')
param pepNsgId string = ''

@description('Route Table ID')
param routeTableId string = ''

@description('Tags to apply to resources')
param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: virtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    dhcpOptions: !empty(dnsServers)
      ? {
          dnsServers: dnsServers
        }
      : null
    subnets: [
      {
        name: masterSubnetName
        properties: {
          addressPrefix: masterSubnetPrefix
          networkSecurityGroup: !empty(masterNsgId)
            ? {
                id: masterNsgId
              }
            : null
          routeTable: !empty(routeTableId)
            ? {
                id: routeTableId
              }
            : null
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.KeyVault'
            }
          ]
          privateLinkServiceNetworkPolicies: 'Enabled'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: workerSubnetName
        properties: {
          addressPrefix: workerSubnetPrefix
          networkSecurityGroup: !empty(workerNsgId)
            ? {
                id: workerNsgId
              }
            : null
          routeTable: !empty(routeTableId)
            ? {
                id: routeTableId
              }
            : null
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.KeyVault'
            }
          ]
          privateLinkServiceNetworkPolicies: 'Enabled'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: dataSubnetName
        properties: {
          addressPrefix: dataSubnetPrefix
          networkSecurityGroup: !empty(dataNsgId)
            ? {
                id: dataNsgId
              }
            : null
          routeTable: !empty(routeTableId)
            ? {
                id: routeTableId
              }
            : null
          delegations: [
            {
              name: 'SqlManagedInstanceDelegation'
              properties: {
                serviceName: 'Microsoft.Sql/managedInstances'
              }
            }
          ]
        }
      }
      {
        name: pepSubnetName
        properties: {
          addressPrefix: pepSubnetPrefix
          networkSecurityGroup: !empty(pepNsgId)
            ? {
                id: pepNsgId
              }
            : null
          routeTable: !empty(routeTableId)
            ? {
                id: routeTableId
              }
            : null
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

output virtualNetworkId string = vnet.id
output virtualNetworkName string = vnet.name
output masterSubnetId string = vnet.properties.subnets[0].id
output workerSubnetId string = vnet.properties.subnets[1].id
output dataSubnetId string = vnet.properties.subnets[2].id
output pepSubnetId string = vnet.properties.subnets[3].id
