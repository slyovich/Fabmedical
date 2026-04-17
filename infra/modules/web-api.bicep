param webApiName string
param location string
param appServicePlanId string
param acrname string
param webapiImageAndTag string = 'nginx'
param identityId string
param identityClientId string
param instrumentationKey string
param connectionString string
param cosmosDbAccountName string
param cosmosDbPrimaryKey string
param mongoDbName string

resource webApi 'Microsoft.Web/sites@2021-01-15' = {
  name: webApiName
  location: location
  kind: 'app,linux,container'
  tags: {
    name: 'content-api'
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
          name: 'MONGODB_CONNECTION'
          value: 'mongodb://${cosmosDbAccountName}:${cosmosDbPrimaryKey}@${cosmosDbAccountName}.mongo.cosmos.azure.com:10255/${mongoDbName}?ssl=true&replicaSet=globaldb&retrywrites=false'
        }
        {
          name: 'WEBSITES_PORT'
          value: '3001'
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
      linuxFxVersion: 'DOCKER|${webapiImageAndTag}'
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
}

output webApiDefaultHostName string = webApi.properties.defaultHostName
