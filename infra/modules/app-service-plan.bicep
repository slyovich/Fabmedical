// ========================================
// Parameters
// ========================================

@description('Azure region for resource deployment')
param location string

@description('Name of the App Service Plan')
param webAppPlanName string

@description('Number of App Service Plan instances')
@minValue(1)
param webAppPlanScaling int = 1

@description('Enable zone redundancy for high availability (requires Premium or Standard SKU)')
param zoneRedundant bool = false

// ========================================
// App Service Plan
// ========================================

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: webAppPlanName
  location: location
  sku: {
    name: 'B1'
    capacity: webAppPlanScaling
  }
  kind: 'linux'
  properties: {
    reserved: true // Required for Linux App Service Plan
    zoneRedundant: zoneRedundant
  }
}

// ========================================
// Outputs
// ========================================

output appServicePlanId string = appServicePlan.id
