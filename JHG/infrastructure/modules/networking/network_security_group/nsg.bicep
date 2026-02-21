@description('Location for all resources')
param location string = resourceGroup().location

@description('Master subnet CIDR')
param masterSubnetCidr string

@description('Worker subnet CIDR')
param workerSubnetCidr string

@description('Data subnet CIDR')
param dataSubnetCidr string

@description('Private Endpoint subnet CIDR')
param pepSubnetCidr string

@description('Jumpbox subnet CIDR')
param jumpboxSubnetCidr string

@description('Hub Firewall IP')
param hubFirewallIp string

@description('NSG Names')
param masterNsgName string
param workerNsgName string
param dataNsgName string
param pepNsgName string


@description('Tags')
param tags object = {}

//////////////////////////////////////////////////////////
// MASTER NSG
//////////////////////////////////////////////////////////

resource masterNsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: masterNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      // 100 - Azure ARO Management
      {
        name: 'Allow-ARO-Management'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'AzureCloud'
          sourcePortRange: '*'
          destinationAddressPrefix: masterSubnetCidr
          destinationPortRanges: [
            '443'
            '6443'
          ]
        }
      }

      // 110 - Worker to Master
      {
        name: 'Allow-Worker-to-Master'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: workerSubnetCidr
          sourcePortRange: '*'
          destinationAddressPrefix: masterSubnetCidr
          destinationPortRanges: [
            '6443'
            '22623'
          ]
        }
      }

      // 120 - Jumpbox SSH
      {
        name: 'Allow-Jumpbox-SSH'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: jumpboxSubnetCidr
          sourcePortRange: '*'
          destinationAddressPrefix: masterSubnetCidr
          destinationPortRange: '22'
        }
      }

      // 130 - Jumpbox API
      {
        name: 'Allow-Jumpbox-API'
        properties: {
          priority: 130
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: jumpboxSubnetCidr
          sourcePortRange: '*'
          destinationAddressPrefix: masterSubnetCidr
          destinationPortRange: '6443'
        }
      }

      // 4096 - Deny All
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

//////////////////////////////////////////////////////////
// WORKER NSG
//////////////////////////////////////////////////////////

resource workerNsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: workerNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [

      // 100 - Master to Worker
      {
        name: 'Allow-Master-to-Worker'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: masterSubnetCidr
          sourcePortRange: '*'
          destinationAddressPrefix: workerSubnetCidr
          destinationPortRanges: [
            '10250'
            '30000-32767'
          ]
        }
      }

      // 110 - Hub Firewall Ingress
      {
        name: 'Allow-Hub-Firewall-HTTPS'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: hubFirewallIp
          sourcePortRange: '*'
          destinationAddressPrefix: workerSubnetCidr
          destinationPortRanges: [
            '80'
            '443'
          ]
        }
      }

      // 120 - Jumpbox SSH
      {
        name: 'Allow-Jumpbox-SSH'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: jumpboxSubnetCidr
          sourcePortRange: '*'
          destinationAddressPrefix: workerSubnetCidr
          destinationPortRange: '22'
        }
      }

      // 130 - Jumpbox HTTPS
      {
        name: 'Allow-Jumpbox-HTTPS'
        properties: {
          priority: 130
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: jumpboxSubnetCidr
          sourcePortRange: '*'
          destinationAddressPrefix: workerSubnetCidr
          destinationPortRange: '443'
        }
      }

      // 4096 - Deny All Inbound
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }

      ///////////////////////////////////////////////////////
      // OUTBOUND RULES
      ///////////////////////////////////////////////////////

      {
        name: 'Allow-SQL-Outbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: workerSubnetCidr
          sourcePortRange: '*'
          destinationAddressPrefix: dataSubnetCidr
          destinationPortRange: '1433'
        }
      }

      {
        name: 'Allow-KeyVault-Outbound'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: workerSubnetCidr
          sourcePortRange: '*'
          destinationAddressPrefix: pepSubnetCidr
          destinationPortRange: '443'
        }
      }

      {
        name: 'Allow-Storage-Outbound'
        properties: {
          priority: 120
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: workerSubnetCidr
          sourcePortRange: '*'
          destinationAddressPrefix: pepSubnetCidr
          destinationPortRange: '445'
        }
      }
    ]
  }
}

//////////////////////////////////////////////////////////
// DATA NSG
//////////////////////////////////////////////////////////

resource dataNsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: dataNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-Worker-SQL'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: workerSubnetCidr
          sourcePortRange: '*'
          destinationAddressPrefix: dataSubnetCidr
          destinationPortRange: '1433'
        }
      }

      {
        name: 'Allow-Hub-Firewall-SQL'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: hubFirewallIp
          sourcePortRange: '*'
          destinationAddressPrefix: dataSubnetCidr
          destinationPortRange: '1433'
        }
      }

      {
        name: 'Allow-Jumpbox-SQL'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: jumpboxSubnetCidr
          sourcePortRange: '*'
          destinationAddressPrefix: dataSubnetCidr
          destinationPortRange: '1433'
        }
      }

      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

//////////////////////////////////////////////////////////
// PEP NSG
//////////////////////////////////////////////////////////

resource pepNsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: pepNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-Worker-HTTPS'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: workerSubnetCidr
          sourcePortRange: '*'
          destinationAddressPrefix: pepSubnetCidr
          destinationPortRange: '443'
        }
      }

      {
        name: 'Allow-Worker-SMB'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: workerSubnetCidr
          sourcePortRange: '*'
          destinationAddressPrefix: pepSubnetCidr
          destinationPortRange: '445'
        }
      }

      {
        name: 'Allow-Jumpbox-HTTPS'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: jumpboxSubnetCidr
          sourcePortRange: '*'
          destinationAddressPrefix: pepSubnetCidr
          destinationPortRange: '443'
        }
      }

      {
        name: 'Allow-Jumpbox-SMB'
        properties: {
          priority: 130
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: jumpboxSubnetCidr
          sourcePortRange: '*'
          destinationAddressPrefix: pepSubnetCidr
          destinationPortRange: '445'
        }
      }

      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

//////////////////////////////////////////////////////////
// OUTPUTS
//////////////////////////////////////////////////////////

output masterNsgId string = masterNsg.id
output workerNsgId string = workerNsg.id
output dataNsgId string = dataNsg.id
output pepNsgId string = pepNsg.id
