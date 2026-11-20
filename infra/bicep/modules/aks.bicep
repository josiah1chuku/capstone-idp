// AKS cluster for the testbed.
// - Entra ID auth with Azure RBAC; local accounts disabled (NFR4).
// - OIDC issuer and workload identity, so services and the control plane use
//   federated identities instead of long-lived secrets (NFR4).
// - Azure Policy add-on, Key Vault CSI driver and Container Insights enabled.
// - Automatic upgrades off, so tool versions stay fixed for the whole experiment.

@description('Azure region.')
param location string

@description('Short name prefix for resources (lowercase letters and digits only).')
param prefix string

@description('Tags applied to every resource.')
param tags object

@description('Kubernetes version, e.g. "1.33". Pinned for reproducible experiments.')
param kubernetesVersion string

@description('VM size for the system node pool (platform components: Argo CD, Kyverno, agents).')
param systemNodeVmSize string

@description('VM size for the user node pool (provisioned services).')
param userNodeVmSize string

@description('Maximum nodes in the autoscaling user pool. Check your regional vCPU quota.')
@minValue(1)
param userNodeMaxCount int

@description('Resource ID of the Log Analytics workspace for Container Insights.')
param logAnalyticsWorkspaceId string

@description('Name of the container registry in this resource group.')
param registryName string

@description('Object ID of the person or group who administers the testbed.')
param adminPrincipalId string

@description('Type of the admin principal.')
@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param adminPrincipalType string

var acrPullRoleId = '7f951dfd-4ca7-4d0c-a2f9-a8dd6d4f16b0'
var aksRbacClusterAdminRoleId = 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b'

resource cluster 'Microsoft.ContainerService/managedClusters@2024-09-01' = {
  name: 'aks-${prefix}'
  location: location
  tags: tags
  sku: {
    name: 'Base'
    tier: 'Free'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: 'aks-${prefix}'
    disableLocalAccounts: true
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      tenantID: tenant().tenantId
    }
    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        type: 'VirtualMachineScaleSets'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        vmSize: systemNodeVmSize
        orchestratorVersion: kubernetesVersion
        count: 1
      }
      {
        name: 'user'
        mode: 'User'
        type: 'VirtualMachineScaleSets'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        vmSize: userNodeVmSize
        orchestratorVersion: kubernetesVersion
        enableAutoScaling: true
        count: 1
        minCount: 1
        maxCount: userNodeMaxCount
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkDataplane: 'cilium'
      networkPolicy: 'cilium'
      loadBalancerSku: 'standard'
    }
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
    addonProfiles: {
      azurepolicy: {
        enabled: true
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
        }
      }
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      }
    }
    autoUpgradeProfile: {
      upgradeChannel: 'none'
      nodeOSUpgradeChannel: 'None'
    }
  }
}

resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: registryName
}

// Lets the nodes pull images from the registry without credentials.
resource kubeletAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, cluster.id, acrPullRoleId)
  scope: registry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: cluster.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

// Gives the admin kubectl access through Entra ID.
resource adminClusterAdmin 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cluster.id, adminPrincipalId, aksRbacClusterAdminRoleId)
  scope: cluster
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', aksRbacClusterAdminRoleId)
    principalId: adminPrincipalId
    principalType: adminPrincipalType
  }
}

output clusterName string = cluster.name
output oidcIssuerUrl string = cluster.properties.oidcIssuerProfile.issuerURL
output nodeResourceGroup string = cluster.properties.nodeResourceGroup
