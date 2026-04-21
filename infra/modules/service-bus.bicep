// ========================================
// Parameters
// ========================================

@description('Name of the Service Bus namespace')
param serviceBusNamespaceName string

@description('Azure region for resource deployment')
param location string

@description('SKU for the Service Bus namespace')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param serviceBusSkuName string = 'Standard'

@description('Name of the queue')
param queueName string = 'notifications'

@description('Queue lock duration (ISO 8601 duration format)')
param lockDuration string = 'PT1M'

@description('Maximum delivery attempts before dead-lettering')
param maxDeliveryCount int = 3

@description('Default message time-to-live (ISO 8601 duration format)')
param defaultMessageTimeToLive string = 'PT1H'

@description('Duplicate detection history time window (ISO 8601 duration format)')
param duplicateDetectionHistoryTimeWindow string = 'PT20S'

@description('Enable dead-lettering on message expiration')
param deadLetteringOnMessageExpiration bool = false

@description('Enable duplicate detection')
param requiresDuplicateDetection bool = false

@description('Enable sessions')
param requiresSession bool = false

// ========================================
// Service Bus Namespace & Queue
// ========================================

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: serviceBusNamespaceName
  location: location
  sku: {
    name: serviceBusSkuName
    tier: serviceBusSkuName
    capacity: 1
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    zoneRedundant: false
  }
}

resource notificationsQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: queueName
  properties: {
    lockDuration: lockDuration
    maxDeliveryCount: maxDeliveryCount
    requiresDuplicateDetection: requiresDuplicateDetection
    requiresSession: requiresSession
    defaultMessageTimeToLive: defaultMessageTimeToLive
    duplicateDetectionHistoryTimeWindow: duplicateDetectionHistoryTimeWindow
    deadLetteringOnMessageExpiration: deadLetteringOnMessageExpiration
    enablePartitioning: false
  }
}

resource namespaceAuthorizationRule 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'fabmedical-shared-access'
  properties: {
    rights: [
      'Listen'
      'Send'
      'Manage'
    ]
  }
}

// ========================================
// Outputs
// ========================================

output serviceBusNamespaceName string = serviceBusNamespace.name
output queueName string = notificationsQueue.name
output authorizationRuleName string = namespaceAuthorizationRule.name
