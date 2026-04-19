@description('Name of the Log Analytics Workspace')
param logAnalyticsWorkspaceName string

@description('Name of the Application Insights instance')
param appInsightsName string

param location string

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appInsightsComponents 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output instrumentationKey string = appInsightsComponents.properties.InstrumentationKey
output connectionString string = appInsightsComponents.properties.ConnectionString
