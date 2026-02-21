// Deploy ONLY Networking Resources for ARO
targetScope = 'resourceGroup'

param environment string = 'non-prod'
param location string = 'australiaeast'

// Sanitize environment name for deployment names (replace spaces with hyphens)
var envSanitized = replace(environment, ' ', '-')

param tags object = {
  owner: 'simran.sah@neudesic.com'
  environment: 'nonprod'
  project: 'EAM'
}

// Networking parameters
param vnetName string = 'eam-net-tst-ae-vnet'
param vnetAddressPrefix string = '10.90.32.0/19'
param dnsServers array = ['10.0.10.15', '10.0.10.16', '10.100.10.10']

// ARO Subnet Configuration
param masterSubnetName string = 'eam-net-tst-ae-snet-aro-master'
param masterSubnetPrefix string = '10.90.32.0/25'
param workerSubnetName string = 'eam-net-tst-ae-snet-aro-worker'
param workerSubnetPrefix string = '10.90.33.0/24'

// Data & PEP Subnet Configuration
param dataSubnetName string = 'eam-net-tst-ae-snet-data'
param dataSubnetPrefix string = '10.90.34.0/24'
param pepSubnetName string = 'eam-net-tst-ae-snet-pep'
param pepSubnetPrefix string = '10.90.35.0/24'

param routeTableName string = 'eam-net-tst-ae-rt-spoke'
  param hubFirewallIp string = '10.0.1.4'

// NSG Names for ARO
param masterNsgName string = 'eam-net-tst-ae-nsg-aro-master'
param workerNsgName string = 'eam-net-tst-ae-nsg-aro-worker'
param dataNsgName string = 'eam-net-tst-ae-nsg-data'
param pepNsgName string = 'eam-net-tst-ae-nsg-pep'

// Jumpbox subnet CIDR (for NSG rules)
param jumpboxSubnetCidr string = ''

// Route Table
module routeTable 'infrastructure/modules/networking/private_endpoint/routetable_spoke.bicep' = {
  name: 'deploy-routetable-${envSanitized}'
  params: {
    routeTableName: routeTableName
    hubFirewallIp: hubFirewallIp
    location: location
    tags: tags
    disableBgpRoutePropagation: false
  }
}

// Network Security Groups (updated for ARO)
module nsgs 'infrastructure/modules/networking/network_security_group/nsg.bicep' = {
  name: 'deploy-nsgs-${envSanitized}'
  params: {
    masterNsgName: masterNsgName
    workerNsgName: workerNsgName
    dataNsgName: dataNsgName
    pepNsgName: pepNsgName
    hubFirewallIp: hubFirewallIp
    masterSubnetCidr: masterSubnetPrefix
    workerSubnetCidr: workerSubnetPrefix
    dataSubnetCidr: dataSubnetPrefix
    pepSubnetCidr: pepSubnetPrefix
    jumpboxSubnetCidr: jumpboxSubnetCidr
    location: location
    tags: tags
  }
}

// Virtual Network with 4 subnets (master, worker, data, pep)
module vnet 'infrastructure/modules/networking/virtual_network/vnet_4subnet.bicep' = {
  name: 'deploy-vnet-${envSanitized}'
  params: {
    virtualNetworkName: vnetName
    addressPrefix: vnetAddressPrefix
    dnsServers: dnsServers
    masterSubnetName: masterSubnetName
    masterSubnetPrefix: masterSubnetPrefix
    workerSubnetName: workerSubnetName
    workerSubnetPrefix: workerSubnetPrefix
    dataSubnetName: dataSubnetName
    dataSubnetPrefix: dataSubnetPrefix
    pepSubnetName: pepSubnetName
    pepSubnetPrefix: pepSubnetPrefix
    masterNsgId: nsgs.outputs.masterNsgId
    workerNsgId: nsgs.outputs.workerNsgId
    dataNsgId: nsgs.outputs.dataNsgId
    pepNsgId: nsgs.outputs.pepNsgId
    routeTableId: routeTable.outputs.routeTableId
    location: location
    tags: tags
  }
}

output vnetId string = vnet.outputs.virtualNetworkId
output masterSubnetId string = vnet.outputs.masterSubnetId
output workerSubnetId string = vnet.outputs.workerSubnetId
output dataSubnetId string = vnet.outputs.dataSubnetId
output pepSubnetId string = vnet.outputs.pepSubnetId
