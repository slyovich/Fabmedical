// ========================================
// Parameters
// ========================================

@description('Name of the content-web Web App')
param webAppName string

@description('Azure region for resource deployment')
param location string

@description('Resource ID of the App Service Plan')
param appServicePlanId string

@description('Name of the Azure Container Registry')
param acrname string

@description('Docker image and tag for content-web')
param webappImageAndTag string = 'nginx'

@description('Resource ID of the User Assigned Managed Identity')
param identityId string

@description('Client ID of the User Assigned Managed Identity')
param identityClientId string

@description('Application Insights Instrumentation Key')
param instrumentationKey string

@description('Application Insights Connection String')
param connectionString string

@description('Hostname of the content-api backend')
param contentApiHostName string

@description('Allowed IP ranges for access restrictions (Zero Trust). Empty array means deny all public traffic.')
param allowedIpRanges array = []

@description('Health check path for monitoring application availability')
param healthCheckPath string = '/health'

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
// Web App (Frontend) App Service
// ========================================

resource webApplication 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  kind: 'app,linux,container'
  tags: {
    name: 'content-web'
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
      linuxFxVersion: 'DOCKER|${webappImageAndTag}'

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
          name: 'CONTENT_API_URL'
          value: 'https://${contentApiHostName}'
        }
        {
          name: 'WEBSITES_PORT'
          value: '3000'
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
resource webAppBasicPublishingCredsFtp 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = {
  parent: webApplication
  name: 'ftp'
  properties: {
    allow: false
  }
}

// --- Disable Basic Auth on SCM (Zero Trust) ---
resource webAppBasicPublishingCredsScm 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = {
  parent: webApplication
  name: 'scm'
  properties: {
    allow: false
  }
}

// ========================================
// Outputs
// ========================================

output webAppDefaultHostName string = webApplication.properties.defaultHostName
