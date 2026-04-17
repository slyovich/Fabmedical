param environment string
param location string
param locationacr string

resource appUserIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'appidentity-brownbag-${environment}-${locationacr}-01'
  location: location 
}

output identityId string = appUserIdentity.id
output identityClientId string = appUserIdentity.properties.clientId
output identityPrincipalId string = appUserIdentity.properties.principalId
