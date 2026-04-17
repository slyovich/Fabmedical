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
param cosmosDbAccountName string

@description('Enable or disable the Cosmos DB free tier')
param enableFreeTierForCosmos bool

@description('Name of the Azure Container Registry')
param acrname string

@description('Number of App Service Plan instances')
param webAppPlanScaling int = 1

@description('Name of the App Service Plan')
param webAppPlanName string

@description('Name of the content-web Web App')
param webAppName string

@description('Docker image and tag for content-web')
param webappImageAndTag string = 'nginx'

@description('Name of the content-api Web App')
param webApiName string

@description('Docker image and tag for content-api')
param webapiImageAndTag string = 'nginx'

@description('Name of the Key Vault')
param keyVaultName string

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
