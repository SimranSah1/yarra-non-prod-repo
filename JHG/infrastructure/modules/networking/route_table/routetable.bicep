@description('Location for all resources.')
param location string = resourceGroup().location

@description('Firewall/NVA IP address for routing')
param firewallIpAddress string = '10.0.1.4'

@description('VNet address prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Tags to apply to the resources')
param tags object = {}

// Frontend Route Table
resource routeTableFrontend 'Microsoft.Network/routeTables@2023-09-01' = {
  name: 'rt-frontend-dev'
  location: location
  tags: union(tags, {
    tier: 'frontend'
  })
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'to-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallIpAddress
        }
      }
      {
        name: 'to-vnet'
        properties: {
          addressPrefix: vnetAddressPrefix
          nextHopType: 'VnetLocal'
        }
      }
    ]
  }
}

// Backend Route Table
resource routeTableBackend 'Microsoft.Network/routeTables@2023-09-01' = {
  name: 'rt-backend-dev'
  location: location
  tags: union(tags, {
    tier: 'backend'
  })
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'to-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallIpAddress
        }
      }
      {
        name: 'to-vnet'
        properties: {
          addressPrefix: vnetAddressPrefix
          nextHopType: 'VnetLocal'
        }
      }
    ]
  }
}

// Database Route Table
resource routeTableDatabase 'Microsoft.Network/routeTables@2023-09-01' = {
  name: 'rt-database-dev'
  location: location
  tags: union(tags, {
    tier: 'database'
  })
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'deny-internet'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'None'
        }
      }
    ]
  }
}

// Management Route Table
resource routeTableManagement 'Microsoft.Network/routeTables@2023-09-01' = {
  name: 'rt-management-dev'
  location: location
  tags: union(tags, {
    tier: 'management'
  })
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'to-internet'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'Internet'
        }
      }
      {
        name: 'to-vnet'
        properties: {
          addressPrefix: vnetAddressPrefix
          nextHopType: 'VnetLocal'
        }
      }
    ]
  }
}

output frontendRouteTableId string = routeTableFrontend.id
output backendRouteTableId string = routeTableBackend.id
output databaseRouteTableId string = routeTableDatabase.id
output managementRouteTableId string = routeTableManagement.id
