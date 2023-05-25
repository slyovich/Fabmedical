param environment string = 'demo'
param location string = 'Switzerland North'
param locationacr string = 'nch'

param cosmosDbAccountName string
param enableFreeTierForCosmos bool

param acrname string

param webAppPlanScaling int = 1

param webAppName string
param webappImageAndTag string = 'nginx'

param webApiName string
param webapiImageAndTag string = 'nginx'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: 'logs-brownbag-${environment}-${locationacr}-01'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appInsightsComponents 'Microsoft.Insights/components@2020-02-02' = {
  name: 'insights-brownbag-${environment}-${locationacr}-01'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2021-03-15' = {
  name: cosmosDbAccountName
  location: location
  kind: 'MongoDB'
  properties: {
    enableFreeTier: enableFreeTierForCosmos
    apiProperties: {
      serverVersion: '4.2'
    }
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxStalenessPrefix: 100
      maxIntervalInSeconds: 5
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: true
    capabilities: [
      {
        name: 'EnableMongo'
      }
      {
        name: 'DisableRateLimitingResponses'
      }
    ]
  }
}

resource mongoDb 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2021-06-15' = {
  name: 'contentdb'
  parent: cosmosDbAccount
  properties: {
    resource: {
      id: 'contentdb'
    }
    options: {
      throughput: 400
    }
  }
}

resource speakersCollection 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections@2023-03-01-preview' = {
  name: 'speakers'
  parent: mongoDb
  properties: {
    resource: {
      id: 'speakers'
      shardKey: {
        _id: 'Hash'
      }
      indexes: [
        {
          key: {
            keys: [
              '_id'
            ]
          }
        }
      ]
    }
  }
}

resource sessionsCollection 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections@2023-03-01-preview' = {
  name: 'sessions'
  parent: mongoDb
  properties: {
    resource: {
      id: 'sessions'
      shardKey: {
        _id: 'Hash'
      }
      indexes: [
        {
          key: {
            keys: [
              '_id'
            ]
          }
        }
        {
          key: {
            keys: [
              'startTime'
            ]
          }
        }
      ]
    }
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: 'plan-brownbag-${environment}-${locationacr}-01'
  location: location
  sku: {
    name: 'B1'
    capacity: webAppPlanScaling
  }
  kind: 'linux'
  properties: {
    reserved: true  //Required for web app for containers
  }
}

resource webApplication 'Microsoft.Web/sites@2021-01-15' = {
  name: webAppName
  location: location
  kind: 'app,linux,container'
  tags: {
    name: 'content-web'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: appUserIdentity.properties.clientId
      http20Enabled: true
      ftpsState: 'Disabled'
      alwaysOn: true
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'CONTENT_API_URL'
          value: 'https://${webApi.properties.defaultHostName}'
        }
        {
          name: 'WEBSITES_PORT'
          value: '3000'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsComponents.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsComponents.properties.ConnectionString
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
      '${appUserIdentity.id}': {}
    }
  }
}

resource webApi 'Microsoft.Web/sites@2021-01-15' = {
  name: webApiName
  location: location
  kind: 'app,linux,container'
  tags: {
    name: 'content-api'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: appUserIdentity.properties.clientId
      http20Enabled: true
      ftpsState: 'Disabled'
      alwaysOn: true
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'MONGODB_CONNECTION'
          value: 'mongodb://${cosmosDbAccount.name}:${cosmosDbAccount.listKeys().primaryMasterKey}@${cosmosDbAccount.name}.mongo.cosmos.azure.com:10255/${mongoDb.name}?ssl=true&replicaSet=globaldb&retrywrites=false'
        }
        {
          name: 'WEBSITES_PORT'
          value: '3001'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsComponents.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsComponents.properties.ConnectionString
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
      '${appUserIdentity.id}': {}
    }
  }
}

// resource acrPullRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
//   scope: resourceGroup()
//   name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
// }

resource appUserIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'appidentity-brownbag-${environment}-${locationacr}-01'
  location: location 
}

// resource webAppRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
//   name: guid(subscription().id, acrname, 'AcrPullAppUserAssigned')
//   properties: {
//     roleDefinitionId: acrPullRoleDefinition.id
//     principalId: appUserIdentity.properties.principalId
//     principalType: 'ServicePrincipal'
//   }
// }
