// ========================================
// Parameters
// ========================================

@description('Azure region for resource deployment')
param location string

@description('Resource ID of the Container App Environment')
param containerAppEnvironmentId string

@description('Login server of the Azure Container Registry (e.g. myacr.azurecr.io)')
param acrLoginServer string

@description('Resource ID of the User Assigned Managed Identity')
param identityId string

@description('Array of container app configurations')
param containerApps containerAppConfig[]

// ========================================
// User-Defined Types
// ========================================

@description('Configuration for a single container app')
type containerAppConfig = {
  @description('Name of the container app')
  name: string

  @description('Docker image and tag (e.g. content-api:latest)')
  imageAndTag: string

  @description('Target port the container listens on')
  targetPort: int

  @description('Enable external ingress (publicly accessible)')
  externalIngress: bool

  @description('Minimum number of replicas')
  minReplicas: int?

  @description('Maximum number of replicas')
  maxReplicas: int?

  @description('Environment variables for the container')
  env: envVar[]?

  @description('Secrets for the container app')
  secrets: secretConfig[]?

  @description('CPU cores allocated to the container (e.g. 0.25, 0.5, 1)')
  cpu: string

  @description('Memory allocated to the container (e.g. 0.5Gi, 1Gi)')
  memory: string

  @description('Dapr App ID for service discovery (omit to disable Dapr)')
  daprAppId: string?

  @description('Port that Dapr uses to communicate with the application')
  daprAppPort: int?

  @description('Protocol used by Dapr to communicate with the app (http or grpc)')
  daprAppProtocol: ('http' | 'grpc')?
}

@description('Environment variable definition')
type envVar = {
  @description('Name of the environment variable')
  name: string

  @description('Plain text value (mutually exclusive with secretRef)')
  value: string?

  @description('Reference to a secret name (mutually exclusive with value)')
  secretRef: string?
}

@description('Secret definition for a container app')
type secretConfig = {
  @description('Name of the secret (used as reference in env vars)')
  name: string

  @description('Key Vault secret URI (if using Key Vault reference instead of inline value)')
  keyVaultUrl: string?
}

// ========================================
// Container Apps
// ========================================

resource apps 'Microsoft.App/containerApps@2026-01-01' = [
  for app in containerApps: {
    name: app.name
    location: location
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${identityId}': {}
      }
    }
    properties: {
      managedEnvironmentId: containerAppEnvironmentId
      workloadProfileName: 'Consumption'
      configuration: {
        // --- Dapr Configuration ---
        dapr: app.?daprAppId != null
          ? {
              enabled: true
              appId: app.daprAppId!
              appPort: app.?daprAppPort ?? app.targetPort
              appProtocol: app.?daprAppProtocol ?? 'http'
            }
          : {
              enabled: false
            }

        identitySettings: [
          {
            identity: identityId
            lifecycle: 'All'
          }
        ]

        // --- ACR Authentication via Managed Identity ---
        registries: [
          {
            server: acrLoginServer
            identity: identityId
          }
        ]

        // --- Ingress ---
        ingress: {
          external: app.externalIngress
          targetPort: app.targetPort
          transport: 'auto'
          allowInsecure: false
          exposedPort: 0
          traffic: [
            {
              weight: 100
              latestRevision: true
            }
          ]
        }

        // --- Secrets ---
        secrets: [
          for secret in (app.?secrets ?? []): {
            name: secret.name
            identity: identityId
            keyVaultUrl: secret.keyVaultUrl
          }
        ]
      }
      template: {
        containers: [
          {
            name: app.name
            image: app.imageAndTag
            resources: {
              cpu: any(app.cpu)
              memory: app.memory
            }
            env: [
              for envItem in (app.?env ?? []): union(
                { name: envItem.name },
                envItem.?secretRef != null ? { secretRef: envItem.secretRef } : { value: envItem.value }
              )
            ]
          }
        ]
        scale: {
          minReplicas: app.?minReplicas ?? 0
          maxReplicas: app.?maxReplicas ?? 3
          cooldownPeriod: 300
          pollingInterval: 30
        }
      }
    }
  }
]

// ========================================
// Outputs
// ========================================

output containerAppFqdns array = [
  for (app, i) in containerApps: {
    name: app.name
    fqdn: apps[i].properties.configuration.ingress.fqdn
  }
]
