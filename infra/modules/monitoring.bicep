param environment string
param location string
param locationacr string

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

output instrumentationKey string = appInsightsComponents.properties.InstrumentationKey
output connectionString string = appInsightsComponents.properties.ConnectionString
