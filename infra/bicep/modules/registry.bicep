// Container registry for service images. Admin user is disabled; AKS pulls with its kubelet identity.

@description('Azure region.')
param location string

@description('Short name prefix for resources (lowercase letters and digits only).')
param prefix string

@description('Tags applied to every resource.')
param tags object

// Registry names are global, 5-50 alphanumeric characters.
var registryName = 'acr${prefix}${uniqueString(resourceGroup().id)}'

resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: registryName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

output registryName string = registry.name
output loginServer string = registry.properties.loginServer
