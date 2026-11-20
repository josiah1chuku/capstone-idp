// Testbed for the policy-guarded IDP: one resource group holding AKS, a container
// registry, Key Vault and Log Analytics, plus an optional subscription cost budget.
// Deployed at subscription scope so the resource group itself is part of the IaC
// and the whole testbed can be deleted and recreated between experiment runs.

targetScope = 'subscription'

@description('Azure region for every resource.')
param location string

@description('Short name prefix for resources: lowercase letters and digits only, 2-8 characters.')
@minLength(2)
@maxLength(8)
param prefix string = 'idp'

@description('Kubernetes version, e.g. "1.33". List options with: az aks get-versions -l <region> -o table')
param kubernetesVersion string

@description('VM size for the system node pool.')
param systemNodeVmSize string = 'Standard_D2s_v5'

@description('VM size for the user node pool.')
param userNodeVmSize string = 'Standard_D2s_v5'

@description('Maximum nodes in the autoscaling user pool. Check your regional vCPU quota.')
@minValue(1)
param userNodeMaxCount int = 2

@description('Object ID of the person or group who administers the testbed (gets cluster admin and Key Vault secrets access).')
param adminPrincipalId string

@description('Type of the admin principal.')
@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param adminPrincipalType string = 'User'

@description('Monthly cost budget for the subscription, in the billing currency.')
param budgetAmount int = 100

@description('Email for budget alerts. Leave empty to skip creating the budget.')
param budgetAlertEmail string = ''

@description('First day of the budget period (yyyy-MM-01). Keep it fixed once the budget exists.')
param budgetStartDate string = ''

@description('Tags applied to every resource.')
param tags object = {
  project: 'capstone-idp'
  environment: 'testbed'
}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${prefix}-testbed'
  location: location
  tags: tags
}

module monitoring 'modules/monitoring.bicep' = {
  scope: rg
  name: 'monitoring'
  params: {
    location: location
    prefix: prefix
    tags: tags
  }
}

module registry 'modules/registry.bicep' = {
  scope: rg
  name: 'registry'
  params: {
    location: location
    prefix: prefix
    tags: tags
  }
}

module keyVault 'modules/keyvault.bicep' = {
  scope: rg
  name: 'keyvault'
  params: {
    location: location
    prefix: prefix
    tags: tags
    adminPrincipalId: adminPrincipalId
    adminPrincipalType: adminPrincipalType
  }
}

module aks 'modules/aks.bicep' = {
  scope: rg
  name: 'aks'
  params: {
    location: location
    prefix: prefix
    tags: tags
    kubernetesVersion: kubernetesVersion
    systemNodeVmSize: systemNodeVmSize
    userNodeVmSize: userNodeVmSize
    userNodeMaxCount: userNodeMaxCount
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    registryName: registry.outputs.registryName
    adminPrincipalId: adminPrincipalId
    adminPrincipalType: adminPrincipalType
  }
}

// Cost guardrail from the proposal's risk table: alert at 80% of actual spend and
// 100% of forecast spend. Lives outside the resource group, so teardown keeps it.
resource budget 'Microsoft.Consumption/budgets@2023-05-01' = if (!empty(budgetAlertEmail) && !empty(budgetStartDate)) {
  name: 'budget-${prefix}-testbed'
  properties: {
    category: 'Cost'
    amount: budgetAmount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: budgetStartDate
    }
    notifications: {
      actual80: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 80
        thresholdType: 'Actual'
        contactEmails: [
          budgetAlertEmail
        ]
      }
      forecast100: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        thresholdType: 'Forecasted'
        contactEmails: [
          budgetAlertEmail
        ]
      }
    }
  }
}

output resourceGroupName string = rg.name
output clusterName string = aks.outputs.clusterName
output oidcIssuerUrl string = aks.outputs.oidcIssuerUrl
output registryLoginServer string = registry.outputs.loginServer
output keyVaultName string = keyVault.outputs.vaultName
output keyVaultUri string = keyVault.outputs.vaultUri
output logAnalyticsWorkspaceId string = monitoring.outputs.workspaceId
