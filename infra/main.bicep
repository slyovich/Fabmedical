// ========================================
// Parameters
// ========================================

@description('Azure region for resource deployment')
param location string = 'Switzerland North'

@description('Name of the Cosmos DB account')
param cosmosDbAccountName string = 'cosmos-fabmedical-chn-001'

@description('Enable or disable the Cosmos DB free tier')
param enableFreeTierForCosmos bool = true

@description('Name of the Azure Container Registry')
param acrname string = 'acrfabmedicalchn001'

// @description('Number of App Service Plan instances')
// param webAppPlanScaling int = 1

// @description('Name of the App Service Plan')
// param webAppPlanName string = 'asp-fabmedical-chn-001'

// @description('Name of the content-web Web App')
// param webAppName string = 'webapp-fabmedical-chn-001'

// @description('Name of the content-api Web App')
// param webApiName string = 'webapi-fabmedical-chn-002'

@description('Docker image and tag for content-web')
param webappImageAndTag string = 'mcr.microsoft.com/k8se/quickstart:latest'

@description('Docker image and tag for content-api')
param webapiImageAndTag string = 'mcr.microsoft.com/k8se/quickstart:latest'

@description('Docker image and tag for content-function')
param functionImageAndTag string = 'mcr.microsoft.com/azure-functions/node:4-node16'

@description('Name of the Key Vault')
param keyVaultName string = 'kv-fabmedical-chn-001'

@description('Name of the Service Bus namespace')
param serviceBusNamespaceName string = 'sb-fabmedical-chn-001'

@description('Name of the Service Bus queue')
param serviceBusQueueName string = 'notifications'

@description('Name of the Storage Account for Azure Functions runtime state')
param storageAccountName string = 'stfabmedicalchn001'

@description('Name of the Container App Environment')
param containerAppEnvironmentName string = 'cae-fabmedical-chn-001'

@description('Name of the User-Assigned Managed Identity')
param managedIdentityName string = 'id-fabmedical-chn-001'

@description('Name of the Log Analytics Workspace')
param logAnalyticsWorkspaceName string = 'logs-fabmedical-chn-001'

@description('Name of the Application Insights instance')
param appInsightsName string = 'ai-fabmedical-chn-001'

@description('Email address for alerts')
param alertEmailAddress string = 'admin@example.com'

// ========================================
// Modules
// ========================================

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoringDeployment'
  params: {
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    appInsightsName: appInsightsName
    alertEmailAddress: alertEmailAddress
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
    managedIdentityName: managedIdentityName
    location: location
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

module serviceBus 'modules/service-bus.bicep' = {
  name: 'serviceBusDeployment'
  params: {
    serviceBusNamespaceName: serviceBusNamespaceName
    location: location
    serviceBusSkuName: 'Standard'
    queueName: serviceBusQueueName
    lockDuration: 'PT1M'
    maxDeliveryCount: 3
    defaultMessageTimeToLive: 'PT1H'
    duplicateDetectionHistoryTimeWindow: 'PT20S'
    deadLetteringOnMessageExpiration: false
    requiresDuplicateDetection: false
    requiresSession: false
  }
}

module storage 'modules/storage-account.bicep' = {
  name: 'storageDeployment'
  params: {
    location: location
    storageAccountName: storageAccountName
  }
}

// module appServicePlan 'modules/app-service-plan.bicep' = {
//   name: 'appServicePlanDeployment'
//   params: {
//     location: location
//     webAppPlanName: webAppPlanName
//     webAppPlanScaling: webAppPlanScaling
//   }
// }

module keyVault 'modules/key-vault.bicep' = {
  name: 'keyVaultDeployment'
  params: {
    keyVaultName: keyVaultName
    location: location
    identityPrincipalId: managedIdentity.outputs.identityPrincipalId
    cosmosDbAccountName: cosmosdb.outputs.cosmosDbAccountName
    mongoDbName: cosmosdb.outputs.mongoDbName
    storageAccountName: storage.outputs.storageAccountName
    serviceBusNamespaceName: serviceBus.outputs.serviceBusNamespaceName
    serviceBusAuthorizationRuleName: serviceBus.outputs.authorizationRuleName
  }
}

// module webApi 'modules/web-api.bicep' = {
//   name: 'webApiDeployment'
//   params: {
//     webApiName: webApiName
//     location: location
//     appServicePlanId: appServicePlan.outputs.appServicePlanId
//     acrname: acrname
//     webapiImageAndTag: webapiImageAndTag
//     identityId: managedIdentity.outputs.identityId
//     identityClientId: managedIdentity.outputs.identityClientId
//     instrumentationKey: monitoring.outputs.instrumentationKey
//     connectionString: monitoring.outputs.connectionString
//     keyVaultName: keyVault.outputs.keyVaultName
//     keyVaultSecretName: keyVault.outputs.mongoDbSecretName
//   }
// }

// module webApp 'modules/web-app.bicep' = {
//   name: 'webAppDeployment'
//   params: {
//     webAppName: webAppName
//     location: location
//     appServicePlanId: appServicePlan.outputs.appServicePlanId
//     acrname: acrname
//     webappImageAndTag: webappImageAndTag
//     identityId: managedIdentity.outputs.identityId
//     identityClientId: managedIdentity.outputs.identityClientId
//     instrumentationKey: monitoring.outputs.instrumentationKey
//     connectionString: monitoring.outputs.connectionString
//     contentApiHostName: webApi.outputs.webApiDefaultHostName
//   }
// }

module containerAppEnvironment 'modules/container-app-environment.bicep' = {
  name: 'containerAppEnvironmentDeployment'
  params: {
    containerAppEnvironmentName: containerAppEnvironmentName
    location: location
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    identityId: managedIdentity.outputs.identityId
    appInsightsConnectionString: monitoring.outputs.connectionString
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
        daprAppId: 'content-api'
        daprAppPort: 3001
        daprAppProtocol: 'http'
        env: [
          {
            name: 'MONGODB_CONNECTION'
            secretRef: 'mongodb-connection-string'
          }
          {
            name: 'SERVICEBUS_CONNECTION'
            secretRef: 'servicebus-connection-string'
          }
          {
            name: 'SERVICEBUS_QUEUE_NAME'
            value: serviceBus.outputs.queueName
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
          {
            name: 'servicebus-connection-string'
            keyVaultUrl: '${keyVault.outputs.keyVaultUri}secrets/${keyVault.outputs.serviceBusSecretName}'
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
        daprAppId: 'content-web'
        daprAppPort: 3000
        daprAppProtocol: 'http'
        env: [
          {
            name: 'CONTENT_API_URL'
            value: 'http://localhost:3500/v1.0/invoke/content-api/method'
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
      {
        name: 'ca-content-function'
        imageAndTag: functionImageAndTag
        targetPort: 80
        externalIngress: false
        minReplicas: 0
        maxReplicas: 3
        scaleRules: [
          {
            name: 'servicebus-queue-50'
            custom: {
              type: 'azure-servicebus'
              metadata: {
                namespace: serviceBus.outputs.serviceBusNamespaceName
                queueName: serviceBus.outputs.queueName
                messageCount: '50'
              }
              auth: [
                {
                  secretRef: 'servicebus-connection-string'
                  triggerParameter: 'connection'
                }
              ]
            }
          }
        ]
        cpu: '0.25'
        memory: '0.5Gi'
        enableHttpProbes: false
        env: [
          {
            name: 'AzureWebJobsStorage'
            secretRef: 'azure-webjobs-storage'
          }
          {
            name: 'FUNCTIONS_WORKER_RUNTIME'
            value: 'node'
          }
          {
            name: 'MONGODB_CONNECTION'
            secretRef: 'mongodb-connection-string'
          }
          {
            name: 'SERVICEBUS_CONNECTION'
            secretRef: 'servicebus-connection-string'
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
          {
            name: 'servicebus-connection-string'
            keyVaultUrl: '${keyVault.outputs.keyVaultUri}secrets/${keyVault.outputs.serviceBusSecretName}'
          }
          {
            name: 'azure-webjobs-storage'
            keyVaultUrl: '${keyVault.outputs.keyVaultUri}secrets/${keyVault.outputs.azureWebJobsStorageSecretName}'
          }
        ]
      }
    ]
  }
}
