// ========================================
// Parameters
// ========================================

@description('Environment name (e.g. demo, dev, prod)')
param environment string = 'demo'

@description('Azure region for resource deployment')
param location string = 'Switzerland North'

@description('Short location code used in resource naming')
param locationacr string = 'chn'

@description('Name of the Cosmos DB account')
param cosmosDbAccountName string = 'cosmos-fabmedical-chn-001'

@description('Enable or disable the Cosmos DB free tier')
param enableFreeTierForCosmos bool = true

@description('Name of the Azure Container Registry')
param acrname string = 'acrfabmedicalchn001'

@description('Number of App Service Plan instances')
param webAppPlanScaling int = 1

@description('Name of the App Service Plan')
param webAppPlanName string = 'asp-fabmedical-chn-001'

@description('Name of the content-web Web App')
param webAppName string = 'webapp-fabmedical-chn-001'

@description('Docker image and tag for content-web')
param webappImageAndTag string = 'mcr.microsoft.com/k8se/quickstart:latest'

@description('Name of the content-api Web App')
param webApiName string = 'webapp-fabmedical-chn-002'

@description('Docker image and tag for content-api')
param webapiImageAndTag string = 'mcr.microsoft.com/k8se/quickstart:latest'

@description('Name of the Key Vault')
param keyVaultName string = 'kv-fabmedical-chn-001'

@description('Name of the Container App Environment')
param containerAppEnvironmentName string = 'cae-fabmedical-chn-001'

// ========================================
// Modules
// ========================================

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoringDeployment'
  params: {
    environment: environment
    location: location
    locationacr: locationacr
  }
}

module cosmosdb 'modules/cosmosdb.bicep' = {
  name: 'cosmosdbDeployment'
  params: {
    cosmosDbAccountName: cosmosDbAccountName
    location: location
    enableFreeTierForCosmos: enableFreeTierForCosmos
  }
}

module managedIdentity 'modules/managed-identity.bicep' = {
  name: 'managedIdentityDeployment'
  params: {
    environment: environment
    location: location
    locationacr: locationacr
  }
}

module acr 'modules/acr.bicep' = {
  name: 'acrDeployment'
  params: {
    acrname: acrname
    location: location
    identityPrincipalId: managedIdentity.outputs.identityPrincipalId
  }
}

module appServicePlan 'modules/app-service-plan.bicep' = {
  name: 'appServicePlanDeployment'
  params: {
    location: location
    webAppPlanName: webAppPlanName
    webAppPlanScaling: webAppPlanScaling
  }
}

module keyVault 'modules/key-vault.bicep' = {
  name: 'keyVaultDeployment'
  params: {
    keyVaultName: keyVaultName
    location: location
    identityPrincipalId: managedIdentity.outputs.identityPrincipalId
    mongoDbConnectionString: 'mongodb://${cosmosdb.outputs.cosmosDbAccountName}:${cosmosdb.outputs.cosmosDbPrimaryKey}@${cosmosdb.outputs.cosmosDbAccountName}.mongo.cosmos.azure.com:10255/${cosmosdb.outputs.mongoDbName}?ssl=true&replicaSet=globaldb&retrywrites=false'
  }
}

module webApi 'modules/web-api.bicep' = {
  name: 'webApiDeployment'
  params: {
    webApiName: webApiName
    location: location
    appServicePlanId: appServicePlan.outputs.appServicePlanId
    acrname: acrname
    webapiImageAndTag: webapiImageAndTag
    identityId: managedIdentity.outputs.identityId
    identityClientId: managedIdentity.outputs.identityClientId
    instrumentationKey: monitoring.outputs.instrumentationKey
    connectionString: monitoring.outputs.connectionString
    keyVaultName: keyVault.outputs.keyVaultName
    keyVaultSecretName: keyVault.outputs.mongoDbSecretName
  }
}

module webApp 'modules/web-app.bicep' = {
  name: 'webAppDeployment'
  params: {
    webAppName: webAppName
    location: location
    appServicePlanId: appServicePlan.outputs.appServicePlanId
    acrname: acrname
    webappImageAndTag: webappImageAndTag
    identityId: managedIdentity.outputs.identityId
    identityClientId: managedIdentity.outputs.identityClientId
    instrumentationKey: monitoring.outputs.instrumentationKey
    connectionString: monitoring.outputs.connectionString
    contentApiHostName: webApi.outputs.webApiDefaultHostName
  }
}

module containerAppEnvironment 'modules/container-app-environment.bicep' = {
  name: 'containerAppEnvironmentDeployment'
  params: {
    containerAppEnvironmentName: containerAppEnvironmentName
    location: location
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    identityId: managedIdentity.outputs.identityId
  }
}

module containerApps 'modules/container-apps.bicep' = {
  name: 'containerAppsDeployment'
  params: {
    location: location
    containerAppEnvironmentId: containerAppEnvironment.outputs.containerAppEnvironmentId
    acrLoginServer: acr.outputs.acrLoginServer
    identityId: managedIdentity.outputs.identityId
    containerApps: [
      {
        name: 'ca-content-api'
        imageAndTag: webapiImageAndTag
        targetPort: 3001
        externalIngress: false
        minReplicas: 0
        maxReplicas: 3
        cpu: '0.25'
        memory: '0.5Gi'
        env: [
          {
            name: 'MONGODB_CONNECTION'
            secretRef: 'mongodb-connection-string'
          }
          {
            name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
            value: monitoring.outputs.instrumentationKey
          }
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: monitoring.outputs.connectionString
          }
        ]
        secrets: [
          {
            name: 'mongodb-connection-string'
            keyVaultUrl: '${keyVault.outputs.keyVaultUri}secrets/${keyVault.outputs.mongoDbSecretName}'
          }
        ]
      }
      {
        name: 'ca-content-web'
        imageAndTag: webappImageAndTag
        targetPort: 3000
        externalIngress: true
        minReplicas: 0
        maxReplicas: 3
        cpu: '0.25'
        memory: '0.5Gi'
        env: [
          {
            name: 'CONTENT_API_URL'
            value: 'https://ca-content-api.internal.${containerAppEnvironment.outputs.defaultDomain}'
          }
          {
            name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
            value: monitoring.outputs.instrumentationKey
          }
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: monitoring.outputs.connectionString
          }
        ]
      }
    ]
  }
}
