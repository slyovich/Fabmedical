// ========================================
// Parameters
// ========================================

@description('Name of the Container App Environment')
param containerAppEnvironmentName string

@description('Azure region for resource deployment')
param location string

@description('Resource ID of the Log Analytics workspace for diagnostics')
param logAnalyticsWorkspaceId string

@description('Enable zone redundancy for high availability')
param zoneRedundant bool = false

@description('Workload profile type (Consumption or Dedicated)')
@allowed([
  'Consumption'
  'D4'
  'D8'
  'D16'
  'D32'
  'E4'
  'E8'
  'E16'
  'E32'
])
param workloadProfileType string = 'Consumption'

@description('Resource ID of the User Assigned Managed Identity')
param identityId string

@description('Application Insights connection string')
@secure()
param appInsightsConnectionString string

// ========================================
// Container App Environment
// ========================================

resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2026-01-01' = {
  name: containerAppEnvironmentName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    infrastructureResourceGroup: 'mrg-${containerAppEnvironmentName}'
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2020-10-01').customerId
        sharedKey: listKeys(logAnalyticsWorkspaceId, '2020-10-01').primarySharedKey
      }
    }
    daprAIConnectionString: appInsightsConnectionString
    publicNetworkAccess: 'Enabled'
    zoneRedundant: zoneRedundant
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: workloadProfileType
      }
    ]
    peerTrafficConfiguration: {
      encryption: {
        enabled: true
      }
    }
    peerAuthentication: {
      mtls: {
        enabled: false
      }
    }
  }
}

// ========================================
// Outputs
// ========================================

output containerAppEnvironmentId string = containerAppEnvironment.id
output containerAppEnvironmentName string = containerAppEnvironment.name
output defaultDomain string = containerAppEnvironment.properties.defaultDomain
