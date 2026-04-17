param webAppName string
param location string
param appServicePlanId string
param acrname string
param webappImageAndTag string = 'nginx'
param identityId string
param identityClientId string
param instrumentationKey string
param connectionString string
param contentApiHostName string

resource webApplication 'Microsoft.Web/sites@2021-01-15' = {
  name: webAppName
  location: location
  kind: 'app,linux,container'
  tags: {
    name: 'content-web'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: identityClientId
      http20Enabled: true
      ftpsState: 'Disabled'
      alwaysOn: true
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'CONTENT_API_URL'
          value: 'https://${contentApiHostName}'
        }
        {
          name: 'WEBSITES_PORT'
          value: '3000'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: instrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: connectionString
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${acrname}.azurecr.io'
        }
      ]
      linuxFxVersion: 'DOCKER|${webappImageAndTag}'
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
}

output webAppDefaultHostName string = webApplication.properties.defaultHostName
