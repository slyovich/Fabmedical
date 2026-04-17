param location string
param webAppPlanName string
param webAppPlanScaling int = 1

resource appServicePlan 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: webAppPlanName
  location: location
  sku: {
    name: 'B1'
    capacity: webAppPlanScaling
  }
  kind: 'linux'
  properties: {
    reserved: true //Required for web app for containers
  }
}

output appServicePlanId string = appServicePlan.id
