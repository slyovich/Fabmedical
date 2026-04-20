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

@description('Email address for alerts')
param alertEmailAddress string

resource actionGroup 'Microsoft.Insights/actionGroups@2022-06-01' = {
  name: 'ag-container-app-alerts'
  location: 'global'
  properties: {
    groupShortName: 'ca-alerts'
    enabled: true
    emailReceivers: [
      {
        name: 'EmailAlert'
        emailAddress: alertEmailAddress
        useCommonAlertSchema: true
      }
    ]
  }
}

resource logAlert 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: 'ContainerAppRevisionError'
  location: location
  properties: {
    description: 'Alert for Container App revision errors'
    severity: 1
    enabled: true
    scopes: [
      logAnalyticsWorkspace.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: 'ContainerAppSystemLogs_CL\n| where Log_s contains "error" or Log_s contains "failed" or Reason_s == "RevisionFailed"'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
  }
}
