@description('Recovery Services Vault name')
param vaultName string

@description('Location for resources')
param location string = resourceGroup().location

@description('SKU name')
@allowed([
  'RS0'
  'Standard'
])
param skuName string = 'Standard'

@description('Tags to apply to resources')
param tags object = {}

resource recoveryServicesVault 'Microsoft.RecoveryServices/vaults@2023-01-01' = {
  name: vaultName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: 'Standard'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
  }
}

// Backup Policy for VMs (Daily 30d, Weekly 5w, Monthly 60m)
resource vmBackupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2023-01-01' = {
  parent: recoveryServicesVault
  name: 'VMBackupPolicy'
  properties: {
    backupManagementType: 'AzureIaasVM'
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicy'
      scheduleRunFrequency: 'Daily'
      scheduleRunTimes: [
        '2023-01-01T02:00:00Z'
      ]
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [
          '2023-01-01T02:00:00Z'
        ]
        retentionDuration: {
          count: 30
          durationType: 'Days'
        }
      }
      weeklySchedule: {
        daysOfTheWeek: [
          'Sunday'
        ]
        retentionTimes: [
          '2023-01-01T02:00:00Z'
        ]
        retentionDuration: {
          count: 5
          durationType: 'Weeks'
        }
      }
      monthlySchedule: {
        retentionScheduleFormatType: 'Weekly'
        retentionScheduleWeekly: {
          daysOfTheWeek: [
            'Sunday'
          ]
          weeksOfTheMonth: [
            'First'
          ]
        }
        retentionTimes: [
          '2023-01-01T02:00:00Z'
        ]
        retentionDuration: {
          count: 60
          durationType: 'Months'
        }
      }
    }
    timeZone: 'UTC'
    instantRpRetentionRangeInDays: 2
  }
}

output vaultId string = recoveryServicesVault.id
output vaultName string = recoveryServicesVault.name
output backupPolicyId string = vmBackupPolicy.id
