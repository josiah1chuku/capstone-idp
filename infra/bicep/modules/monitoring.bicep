// Log Analytics workspace for Container Insights (cluster and service logs and metrics).

@description('Azure region.')
param location string

@description('Short name prefix for resources.')
param prefix string

@description('Tags applied to every resource.')
param tags object

@description('Daily ingestion cap in GB. Keeps the testbed inside a student budget.')
param dailyQuotaGb int = 1

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-${prefix}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: dailyQuotaGb
    }
  }
}

output workspaceId string = workspace.id
output workspaceName string = workspace.name
