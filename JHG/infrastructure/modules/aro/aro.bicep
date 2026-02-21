@description('Azure Red Hat OpenShift (ARO) Cluster name')
param clusterName string

@description('Location for resources')
param location string = resourceGroup().location

@description('Master subnet ID')
param masterSubnetId string

@description('Worker subnet ID')
param workerSubnetId string

@description('ARO cluster version')
param clusterVersion string = '4.14.0'

@description('Pod CIDR for ARO')
param podCidr string = '10.128.0.0/14'

@description('Service CIDR for ARO')
param serviceCidr string = '172.30.0.0/16'

@description('Outbound type')
param outboundType string = 'Loadbalancer'

@description('Pull secret (base64 encoded)')
@secure()
param pullSecret string = ''

@description('Worker VM size')
param workerVmSize string = 'Standard_D16s_v5'

@description('Worker node disk size in GB')
param workerDiskSize int = 128

@description('Number of worker nodes')
param workerCount int = 3

@description('Master VM size')
param masterVmSize string = 'Standard_D8s_v5'

@description('API Server visibility')
param apiVisibility string = 'Private'

@description('Ingress visibility')
param ingressVisibility string = 'Private'

@description('ARO cluster domain')
param aroDomain string = ''

@description('Tags to apply to resources')
param tags object = {}

// Azure Red Hat OpenShift Cluster
resource aroCluster 'Microsoft.RedHatOpenShift/openShiftClusters@2023-09-04' = {
  name: clusterName
  location: location
  tags: tags
  properties: {
    clusterProfile: {
      domain: !empty(aroDomain) ? replace(toLower(aroDomain), '.', '-') : replace(toLower(clusterName), '-', '')
      version: clusterVersion
      pullSecret: !empty(pullSecret) ? pullSecret : null
      fipsValidatedModules: 'Disabled'
    }
    networkProfile: {
      podCidr: podCidr
      serviceCidr: serviceCidr
      outboundType: outboundType
    }
    masterProfile: {
      vmSize: masterVmSize
      subnetId: masterSubnetId
      encryptionAtHost: 'Disabled'
    }
    workerProfiles: [
      {
        name: 'worker'
        vmSize: workerVmSize
        diskSizeGB: workerDiskSize
        subnetId: workerSubnetId
        count: workerCount
        encryptionAtHost: 'Disabled'
      }
    ]
    apiserverProfile: {
      visibility: apiVisibility
    }
    ingressProfiles: [
      {
        name: 'default'
        visibility: ingressVisibility
      }
    ]
  }
}

@description('ARO Cluster ID')
output clusterId string = aroCluster.id

@description('ARO Cluster Name')
output clusterName string = aroCluster.name

@description('ARO API Server URL')
output apiServerUrl string = aroCluster.properties.apiserverProfile.url

@description('ARO Ingress IP')
output ingressIp string = aroCluster.properties.ingressProfiles[0].ip

@description('ARO Console URL')
output consoleUrl string = 'https://console-openshift-console.apps.${aroCluster.properties.ingressProfiles[0].ip}'
