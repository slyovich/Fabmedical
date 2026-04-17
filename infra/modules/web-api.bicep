// ========================================
// Parameters
// ========================================

@description('Name of the content-api Web App')
param webApiName string

@description('Azure region for resource deployment')
param location string

@description('Resource ID of the App Service Plan')
param appServicePlanId string

@description('Name of the Azure Container Registry')
param acrname string

@description('Docker image and tag for content-api')
param webapiImageAndTag string = 'nginx'

@description('Resource ID of the User Assigned Managed Identity')
param identityId string

@description('Client ID of the User Assigned Managed Identity')
param identityClientId string

@description('Application Insights Instrumentation Key')
param instrumentationKey string

@description('Application Insights Connection String')
param connectionString string

@description('Name of the Key Vault containing the MongoDB connection string secret')
param keyVaultName string

@description('Name of the Key Vault secret containing the MongoDB connection string')
param keyVaultSecretName string

@description('Allowed IP ranges for access restrictions (Zero Trust). Empty array means deny all public traffic.')
param allowedIpRanges array = []

@description('Health check path for monitoring application availability')
param healthCheckPath string = '/api/health'

// ========================================
// Variables
// ========================================

var allowedIpRules = [for (ipRange, i) in allowedIpRanges: {
  ipAddress: ipRange
  action: 'Allow'
  priority: 100 + i
  name: 'AllowedIP-${i}'
}]

var denyAllRule = [
  {
    ipAddress: 'Any'
    action: 'Deny'
    priority: 2147483647
    name: 'DenyAll'
  }
]

var ipSecurityRules = concat(allowedIpRules, denyAllRule)

// ========================================
// Web API App Service
// ========================================

resource webApi 'Microsoft.Web/sites@2023-12-01' = {
  name: webApiName
  location: location
  kind: 'app,linux,container'
  tags: {
    name: 'content-api'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true // Force HTTPS — redirect all HTTP traffic
    clientCertEnabled: false // Set to true to require client certificates (mTLS)
    clientCertMode: 'OptionalInteractiveUser'
    publicNetworkAccess: 'Enabled' // Set to 'Disabled' when using Private Endpoints
    siteConfig: {
      // --- Container / ACR Authentication ---
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: identityClientId
      linuxFxVersion: 'DOCKER|${webapiImageAndTag}'

      // --- TLS & Protocol Hardening ---
      http20Enabled: true
      minTlsVersion: '1.3'
      scmMinTlsVersion: '1.3'

      // --- Disable Unnecessary Services (Attack Surface Reduction) ---
      ftpsState: 'Disabled'
      remoteDebuggingEnabled: false
      webSocketsEnabled: false // Enable only if needed

      // --- Availability ---
      alwaysOn: true
      healthCheckPath: healthCheckPath

      // --- Access Restrictions (Zero Trust: Deny by default) ---
      ipSecurityRestrictions: ipSecurityRules
      // SCM site restrictions — lock down deployment endpoint
      scmIpSecurityRestrictionsUseMain: true

      // --- Application Settings ---
      appSettings: [
        {
          name: 'MONGODB_CONNECTION'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${keyVaultSecretName})'
        }
        {
          name: 'WEBSITES_PORT'
          value: '3001'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: instrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: connectionString
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${acrname}.azurecr.io'
        }
        {
          // Disable basic auth for SCM (Zero Trust: use Entra ID instead)
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'false'
        }
      ]

      // --- Detailed Error & Logging ---
      detailedErrorLoggingEnabled: false // Prevent leaking sensitive info in errors
      httpLoggingEnabled: true
      requestTracingEnabled: true
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
}

// --- Disable Basic Auth on FTP (Zero Trust) ---
resource webApiBasicPublishingCredsFtp 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = {
  parent: webApi
  name: 'ftp'
  properties: {
    allow: false
  }
}

// --- Disable Basic Auth on SCM (Zero Trust) ---
resource webApiBasicPublishingCredsScm 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = {
  parent: webApi
  name: 'scm'
  properties: {
    allow: false
  }
}

// ========================================
// Outputs
// ========================================

output webApiDefaultHostName string = webApi.properties.defaultHostName
