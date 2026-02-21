targetScope = 'subscription'

@description('Enable or disable Microsoft Defender for Servers')
param enableDefender bool = true

@description('Defender for Servers plan')
@allowed([
  'Standard'
  'P2'
])
param serverPlan string = 'Standard'

resource defenderForServers 'Microsoft.Security/pricings@2024-01-01' = if (enableDefender) {
  name: 'VirtualMachines'
  properties: {
    pricingTier: 'Standard'
    subPlan: serverPlan == 'P2' ? 'P2' : null
  }
}

@description('Whether Defender for Servers is enabled')
output defenderEnabled bool = enableDefender

@description('Selected Defender plan')
output defenderPlan string = serverPlan

@description('Defender resource ID')
output defenderResourceId string = enableDefender ? defenderForServers.id : ''
