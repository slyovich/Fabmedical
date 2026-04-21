// ========================================
// Parameters
// ========================================

@description('Name of the Key Vault')
param keyVaultName string

@description('Azure region for resource deployment')
param location string

@description('Tenant ID for the Key Vault (defaults to current tenant)')
param tenantId string = subscription().tenantId

@description('Principal ID of the Managed Identity that needs access to secrets')
param identityPrincipalId string

@description('Name of the Cosmos DB account')
param cosmosDbAccountName string

@description('Name of the MongoDB database')
param mongoDbName string

@description('Name of the Storage Account for Azure Functions runtime state')
param storageAccountName string

@description('Name of the Service Bus namespace')
param serviceBusNamespaceName string

@description('Name of the Service Bus authorization rule')
param serviceBusAuthorizationRuleName string

// ========================================
// Key Vault
// ========================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }

    // --- Zero Trust: RBAC-based access (no access policies) ---
    enableRbacAuthorization: true

    // --- Network hardening ---
    publicNetworkAccess: 'Enabled' // Set to 'Disabled' when using Private Endpoints
    networkAcls: {
      defaultAction: 'Allow' // Restrict to 'Deny' + VNet rules in production
      bypass: 'AzureServices' // Allow trusted Azure services (e.g., App Service)
    }

    // --- Soft delete & purge protection ---
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
  }
}

// ========================================
// Secrets
// ========================================

resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' existing = {
  name: cosmosDbAccountName
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' existing = {
  name: serviceBusNamespaceName
}

resource serviceBusAuthorizationRule 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2022-10-01-preview' existing = {
  parent: serviceBusNamespace
  name: serviceBusAuthorizationRuleName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource mongoDbSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'mongodb-connection-string'
  properties: {
    value: 'mongodb://${cosmosDbAccountName}:${cosmosDb.listKeys().primaryMasterKey}@${cosmosDbAccountName}.mongo.cosmos.azure.com:10255/${mongoDbName}?ssl=true&replicaSet=globaldb&retrywrites=false'
    contentType: 'text/plain'
  }
}

resource serviceBusSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'servicebus-connection-string'
  properties: {
    value: serviceBusAuthorizationRule.listKeys().primaryConnectionString
    contentType: 'text/plain'
  }
}

resource azureWebJobsStorageSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'azure-webjobs-storage'
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
    contentType: 'text/plain'
  }
}

// ========================================
// RBAC — Key Vault Secrets User
// Role ID: 4633458b-17de-408a-b874-0445c86b69e6
// Grants: Secret Get + List
// ========================================

resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, identityPrincipalId, keyVaultSecretsUserRole.id)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: identityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ========================================
// Outputs
// ========================================

output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output mongoDbSecretName string = mongoDbSecret.name
output serviceBusSecretName string = serviceBusSecret.name
output azureWebJobsStorageSecretName string = azureWebJobsStorageSecret.name
