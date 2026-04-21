// ========================================
// Parameters
// ========================================

@description('Name of the Storage Account')
param storageAccountName string

@description('Azure region for resource deployment')
param location string

// ========================================
// Storage Account
// ========================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    accessTier: 'Hot'
  }
}

// ========================================
// Outputs
// ========================================

output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
