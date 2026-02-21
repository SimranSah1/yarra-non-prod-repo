@description('Name of the local virtual network')
param localVnetName string

@description('Resource ID of the remote virtual network')
param remoteVnetId string

@description('Name of the peering from local to remote')
param peeringName string

@description('Allow virtual network access')
param allowVirtualNetworkAccess bool = true

@description('Allow forwarded traffic from remote virtual network')
param allowForwardedTraffic bool = false

@description('Allow gateway transit')
param allowGatewayTransit bool = false

@description('Use remote gateways')
param useRemoteGateways bool = false

resource localVnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: localVnetName
}

resource vnetPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: localVnet
  name: peeringName
  properties: {
    allowVirtualNetworkAccess: allowVirtualNetworkAccess
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    useRemoteGateways: useRemoteGateways
    remoteVirtualNetwork: {
      id: remoteVnetId
    }
  }
}

output peeringId string = vnetPeering.id
output peeringName string = vnetPeering.name
output peeringState string = vnetPeering.properties.peeringState
