param cosmosDbAccountName string
param location string
param enableFreeTierForCosmos bool

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2021-03-15' = {
  name: cosmosDbAccountName
  location: location
  kind: 'MongoDB'
  properties: {
    defaultIdentity: 'FirstPartyIdentity'
    enableFreeTier: enableFreeTierForCosmos
    apiProperties: {
      serverVersion: '4.2'
    }
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxStalenessPrefix: 100
      maxIntervalInSeconds: 5
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: true
    capabilities: [
      {
        name: 'EnableMongo'
      }
      {
        name: 'DisableRateLimitingResponses'
      }
    ]
  }
}

resource mongoDb 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2021-06-15' = {
  name: 'contentdb'
  parent: cosmosDbAccount
  properties: {
    resource: {
      id: 'contentdb'
    }
    options: {
      throughput: 400
    }
  }
}

resource speakersCollection 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections@2023-03-01-preview' = {
  name: 'speakers'
  parent: mongoDb
  properties: {
    resource: {
      id: 'speakers'
      shardKey: {
        _id: 'Hash'
      }
      indexes: [
        {
          key: {
            keys: [
              '_id'
            ]
          }
        }
      ]
    }
  }
}

resource sessionsCollection 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections@2023-03-01-preview' = {
  name: 'sessions'
  parent: mongoDb
  properties: {
    resource: {
      id: 'sessions'
      shardKey: {
        _id: 'Hash'
      }
      indexes: [
        {
          key: {
            keys: [
              '_id'
            ]
          }
        }
        {
          key: {
            keys: [
              'startTime'
            ]
          }
        }
      ]
    }
  }
}

output cosmosDbAccountName string = cosmosDbAccount.name
output cosmosDbPrimaryKey string = cosmosDbAccount.listKeys().primaryMasterKey
output mongoDbName string = mongoDb.name
