@description('Route table name')
param routeTableName string

@description('Location for resources')
param location string = resourceGroup().location

@description('Hub firewall IP address')
param hubFirewallIp string

@description('Enable BGP route propagation')
param disableBgpRoutePropagation bool = false

@description('Tags to apply to resources')
param tags object = {}

resource routeTable 'Microsoft.Network/routeTables@2023-05-01' = {
  name: routeTableName
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: disableBgpRoutePropagation
    routes: [
      {
        name: 'route-to-hub-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: hubFirewallIp
        }
      }
    ]
  }
}

output routeTableId string = routeTable.id
output routeTableName string = routeTable.name
