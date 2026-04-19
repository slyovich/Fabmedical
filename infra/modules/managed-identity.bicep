@description('Name of the User-Assigned Managed Identity')
param managedIdentityName string

param location string

resource appUserIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location 
}

output identityId string = appUserIdentity.id
output identityClientId string = appUserIdentity.properties.clientId
output identityPrincipalId string = appUserIdentity.properties.principalId
