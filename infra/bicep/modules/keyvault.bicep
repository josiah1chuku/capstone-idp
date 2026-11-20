// Key Vault for service secrets (FR5). RBAC authorization only, no access policies.
// Services read secrets through the Secrets Store CSI driver with workload identity;
// the control plane grants each service's identity access when it provisions the service.

@description('Azure region.')
param location string

@description('Short name prefix for resources (lowercase letters and digits only).')
param prefix string

@description('Tags applied to every resource.')
param tags object

@description('Object ID of the person or group who administers the testbed.')
param adminPrincipalId string

@description('Type of the admin principal.')
@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param adminPrincipalType string

// Vault names are global, 3-24 characters. Deterministic per resource group, so the
// teardown script purges the soft-deleted vault to let the next deploy reuse the name.
var vaultName = 'kv-${prefix}-${take(uniqueString(resourceGroup().id), 8)}'

var keyVaultSecretsOfficerRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'

resource vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: vaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    // Purge protection is deliberately not enabled, so the testbed can be torn down
    // and recreated between experiment runs. Enabling it cannot be undone.
    publicNetworkAccess: 'Enabled'
  }
}

resource adminSecretsOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, adminPrincipalId, keyVaultSecretsOfficerRoleId)
  scope: vault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsOfficerRoleId)
    principalId: adminPrincipalId
    principalType: adminPrincipalType
  }
}

output vaultName string = vault.name
output vaultUri string = vault.properties.vaultUri
