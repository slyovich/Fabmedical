param acrname string
param location string = 'Switzerland North'
param identityPrincipalId string

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  name: acrname
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
  }
}

resource acrPullRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(subscription().id, acrname, 'AcrPullAppUserAssigned')
  properties: {
    roleDefinitionId: acrPullRoleDefinition.id
    principalId: identityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output acrLoginServer string = containerRegistry.properties.loginServer
