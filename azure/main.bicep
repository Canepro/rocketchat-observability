targetScope = 'resourceGroup'

@description('Azure region to deploy to.')
param location string = 'uksouth'

@description('Container Apps Environment name')
param environmentName string = 'rocketchat-env'

@description('DNS domain used by Rocket.Chat')
param domain string = 'chat.canepro.me'

@description('Grafana admin password stored as an ACA secret')
@secure()
param grafanaAdminPassword string

@description('MongoDB replica set name')
param mongoReplicaSetName string = 'rs0'

@description('Container Registry name (lowercase, globally unique). Will be created if it does not exist.')
param acrName string = toLower('rcobs${uniqueString(resourceGroup().id)}')

@description('The image tag to use for the Rocket.Chat container.')
param rocketchatImageTag string = 'latest'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'rc-logs-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

resource cae 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: environmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

var commonSecrets = [
  {
    name: 'acr-pwd'
    value: acr.listCredentials().passwords[0].value
  }
]

var commonRegistries = [
  {
    server: acr.properties.loginServer
    username: acr.listCredentials().username
    passwordSecretRef: 'acr-pwd'
  }
]

resource mongo 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'mongo'
  location: location
  properties: {
    managedEnvironmentId: cae.id
    configuration: {
      secrets: commonSecrets
      registries: commonRegistries
      ingress: {
        external: false
        targetPort: 27017
        transport: 'auto'
      }
    }
    template: {
      containers: [
        {
          name: 'mongo'
          image: '${acr.properties.loginServer}/mongo:latest'
          env: [
            {
              name: 'ALLOW_EMPTY_PASSWORD'
              value: 'yes'
            }
            {
              name: 'MONGODB_REPLICA_SET_MODE'
              value: 'primary'
            }
            {
              name: 'MONGODB_REPLICA_SET_NAME'
              value: mongoReplicaSetName
            }
          ]
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

resource nats 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'nats'
  location: location
  properties: {
    managedEnvironmentId: cae.id
    configuration: {
      secrets: commonSecrets
      registries: commonRegistries
      ingress: {
        external: false
        targetPort: 8222
      }
    }
    template: {
      containers: [
        {
          name: 'nats'
          image: '${acr.properties.loginServer}/nats:latest'
          command: [
            '--http_port'
            '8222'
          ]
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

resource mongodbExporter 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'mongodb-exporter'
  location: location
  properties: {
    managedEnvironmentId: cae.id
    configuration: {
      secrets: commonSecrets
      registries: commonRegistries
      ingress: {
        external: false
        targetPort: 9216
      }
    }
    template: {
      containers: [
        {
          name: 'mongodb-exporter'
          image: '${acr.properties.loginServer}/mongodb-exporter:latest'
          env: [
            {
              name: 'MONGODB_URI'
              value: 'mongodb://mongo:27017'
            }
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

resource natsExporter 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'nats-exporter'
  location: location
  properties: {
    managedEnvironmentId: cae.id
    configuration: {
      secrets: commonSecrets
      registries: commonRegistries
      ingress: {
        external: false
        targetPort: 7777
      }
    }
    template: {
      containers: [
        {
          name: 'nats-exporter'
          image: '${acr.properties.loginServer}/nats-exporter:latest'
          command: [
            '-varz'
            '-connz'
            'http://nats:8222'
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

resource prometheus 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'prometheus'
  location: location
  properties: {
    managedEnvironmentId: cae.id
    configuration: {
      secrets: commonSecrets
      registries: commonRegistries
      ingress: {
        external: false
        targetPort: 9090
      }
    }
    template: {
      containers: [
        {
          name: 'prometheus'
          image: '${acr.properties.loginServer}/prometheus:latest'
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

resource grafana 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'grafana'
  location: location
  properties: {
    managedEnvironmentId: cae.id
    configuration: {
      secrets: union(commonSecrets, [
        {
          name: 'grafana-admin-password'
          value: grafanaAdminPassword
        }
      ])
      registries: commonRegistries
      ingress: {
        external: false
        targetPort: 3000
      }
    }
    template: {
      containers: [
        {
          name: 'grafana'
          image: '${acr.properties.loginServer}/grafana:latest'
          env: [
            {
              name: 'GF_SERVER_ROOT_URL'
              value: 'https://${domain}/grafana'
            }
            {
              name: 'GF_SERVER_SERVE_FROM_SUB_PATH'
              value: 'true'
            }
            {
              name: 'GF_SECURITY_ADMIN_PASSWORD'
              secretRef: 'grafana-admin-password'
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 2
      }
    }
  }
}

resource rocketchat 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'rocketchat'
  location: location
  properties: {
    managedEnvironmentId: cae.id
    configuration: {
      secrets: commonSecrets
      registries: commonRegistries
      ingress: {
        external: true
        targetPort: 3000
        transport: 'auto'
      }
    }
    template: {
      containers: [
        {
          name: 'rocketchat'
          image: '${acr.properties.loginServer}/rocketchat:${rocketchatImageTag}'
          env: [
            {
              name: 'MONGO_URL'
              value: 'mongodb://mongo:27017/rocketchat?replicaSet=${mongoReplicaSetName}'
            }
            {
              name: 'ROOT_URL'
              value: 'https://${domain}'
            }
            {
              name: 'TRANSPORTER'
              value: 'nats://nats:4222'
            }
            {
              name: 'OVERWRITE_SETTING_Prometheus_Enabled'
              value: 'true'
            }
            {
              name: 'OVERWRITE_SETTING_Prometheus_Port'
              value: '9458'
            }
          ]
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
        rules: [
          {
            name: 'http-concurrency'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

resource mongoInitJob 'Microsoft.App/jobs@2023-05-01' = {
  name: 'mongo-init-replica'
  location: location
  properties: {
    environmentId: cae.id
    configuration: {
      triggerType: 'Manual'
      replicaRetryLimit: 1
      replicaTimeout: 1800
      manualTriggerConfig: {
        parallelism: 1
        replicaCompletionCount: 1
      }
    }
    template: {
      containers: [
        {
          name: 'mongo-init'
          image: '${acr.properties.loginServer}/mongo:latest'
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
          command: [
            'bash'
            '-c'
            'sleep 10 && echo "Initializing MongoDB replica set..." && mongosh --host mongo --port 27017 --eval "try { const s = rs.status(); if (s.ok === 1) { print(\\"Replica set already initialized\\"); quit(0); } } catch (e) { } rs.initiate({ _id: \\"${mongoReplicaSetName}\\", members: [ { _id: 0, host: \\"mongo:27017\\" } ] });" || true'
          ]
        }
      ]
    }
  }
}

output containerRegistryName string = acr.name
output containerRegistryLoginServer string = acr.properties.loginServer
output environmentId string = cae.id
output rocketchatFqdn string = rocketchat.properties.configuration.ingress.fqdn
