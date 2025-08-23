targetScope = 'resourceGroup'

@description('Azure region to deploy to.')
param location string = 'uksouth'

@description('Resource group name (informational).')
param resourceGroupName string = 'Rocketchat_RG'

@description('Container Apps Environment name')
param environmentName string = 'rocketchat-env'

@description('DNS domain used by Rocket.Chat')
param domain string = 'chat.canepro.me'

@description('Grafana admin password stored as an ACA secret')
@secure()
param grafanaAdminPassword string = 'rc-admin'

@description('MongoDB replica set name')
param mongoReplicaSetName string = 'rs0'

@description('Container Registry name (lowercase, globally unique). Will be created if it does not exist.')
param acrName string = toLower('rcobs${uniqueString(resourceGroup().id)}')

// ---------------------------------------------
// Logging - Log Analytics Workspace
// ---------------------------------------------
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

// ---------------------------------------------
// Azure Container Registry (Basic, admin enabled)
// ---------------------------------------------
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

var acrCreds = listCredentials(acr.id, '2023-07-01')
var acrServer = acr.properties.loginServer
var acrUser = acrCreds.username
var acrPwd  = acrCreds.passwords[0].value

// ---------------------------------------------
// Container Apps Environment
// ---------------------------------------------
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

// ---------------------------------------------
// Common config helpers
// ---------------------------------------------
var commonSecrets = [
	{
		name: 'acr-pwd'
		value: acrPwd
	}
]

var commonRegistries = [
	{
		server: acrServer
		username: acrUser
		passwordSecretRef: 'acr-pwd'
	}
]

// ---------------------------------------------
// mongo (internal)
// ---------------------------------------------
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
					image: '${acrServer}/mongo:latest'
					env: [
						{ name: 'ALLOW_EMPTY_PASSWORD', value: 'yes' }
						{ name: 'MONGODB_REPLICA_SET_MODE', value: 'primary' }
						{ name: 'MONGODB_REPLICA_SET_NAME', value: mongoReplicaSetName }
					]
					resources: {
						cpu: 1.0
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

// ---------------------------------------------
// nats (internal)
// ---------------------------------------------
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
			}
		}
		template: {
			containers: [
				{
					name: 'nats'
					image: '${acrServer}/nats:latest'
					command: [ '--http_port', '8222' ]
					resources: {
						cpu: 0.5
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

// ---------------------------------------------
// mongodb-exporter (internal)
// ---------------------------------------------
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
			}
		}
		template: {
			containers: [
				{
					name: 'mongodb-exporter'
					image: '${acrServer}/mongodb-exporter:latest'
					env: [ { name: 'MONGODB_URI', value: 'mongodb://mongo:27017' } ]
					resources: {
						cpu: 0.25
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

// ---------------------------------------------
// nats-exporter (internal)
// ---------------------------------------------
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
			}
		}
		template: {
			containers: [
				{
					name: 'nats-exporter'
					image: '${acrServer}/nats-exporter:latest'
					command: [ '-varz', '-connz', 'http://nats:8222' ]
					resources: {
						cpu: 0.25
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

// ---------------------------------------------
// prometheus (internal)
// ---------------------------------------------
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
			}
		}
		template: {
			containers: [
				{
					name: 'prometheus'
					image: '${acrServer}/prometheus:latest'
					command: [
						'--web.console.templates=/usr/share/prometheus/consoles',
						'--config.file=/etc/prometheus/prometheus.yml',
						'--web.enable-lifecycle',
						'--web.listen-address=:9090',
						'--storage.tsdb.path=/prometheus/data',
						'--config.auto-reload-interval=30s',
						'--auto-gomaxprocs',
						'--storage.tsdb.retention.size=15GB',
						'--storage.tsdb.retention.time=15d'
					]
					resources: {
						cpu: 0.5
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

// ---------------------------------------------
// grafana (internal; secret for admin password)
// ---------------------------------------------
resource grafana 'Microsoft.App/containerApps@2023-05-01' = {
	name: 'grafana'
	location: location
	properties: {
		managedEnvironmentId: cae.id
		configuration: {
			secrets: union(commonSecrets, [ { name: 'grafana-admin-password', value: grafanaAdminPassword } ])
			registries: commonRegistries
			ingress: {
				external: false
				targetPort: 3000
				transport: 'auto'
			}
		}
		template: {
			containers: [
				{
					name: 'grafana'
					image: '${acrServer}/grafana:latest'
					env: [
						{ name: 'GF_SERVER_ROOT_URL', value: 'https://${domain}/grafana' },
						{ name: 'GF_SERVER_SERVE_FROM_SUB_PATH', value: 'true' },
						{ name: 'GF_SECURITY_ADMIN_PASSWORD', secretRef: 'grafana-admin-password' }
					]
					resources: {
						cpu: 0.5
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

// ---------------------------------------------
// rocketchat (single external ingress).
// NOTE: Path-based routing to internal Grafana is defined via routes/backends.
// ---------------------------------------------
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
				traffic: [ { latestRevision: true, weight: 100 } ]
				// The following routes/backends are available in newer ACA API versions.
				// If your subscription doesn't support this yet, configure the routes via Azure CLI after deployment:
				// az containerapp ingress route add --name rocketchat --resource-group ${resourceGroupName} --app-endpoint /grafana --service grafana --service-port 3000 --rewrite-target /
				//
				// routes: [
				//   {
				//     name: 'grafana'
				//     match: [ { path: '/grafana(/|$)(.*)' } ]
				//     destination: 'grafana-backend'
				//     rewrite: '/$2'
				//   }
				// ]
				// backends: [
				//   { name: 'rocketchat-backend', service: 'rocketchat', port: 3000 },
				//   { name: 'grafana-backend', service: 'grafana', port: 3000 }
				// ]
			}
		}
		template: {
			containers: [
				{
					name: 'rocketchat'
					image: '${acrServer}/rocketchat:latest'
					env: [
						{ name: 'MONGO_URL', value: 'mongodb://mongo:27017/rocketchat?replicaSet=${mongoReplicaSetName}' },
						{ name: 'ROOT_URL', value: 'https://${domain}' },
						{ name: 'TRANSPORTER', value: 'nats://nats:4222' },
						{ name: 'OVERWRITE_SETTING_Prometheus_Enabled', value: 'true' },
						{ name: 'OVERWRITE_SETTING_Prometheus_Port', value: '9458' }
					]
					resources: {
						cpu: 1.0
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

// ---------------------------------------------
// ACA Job: mongo-init-replica (manual trigger)
// ---------------------------------------------
resource mongoInitJob 'Microsoft.App/jobs@2023-05-01' = {
	name: 'mongo-init-replica'
	location: location
	properties: {
		environmentId: cae.id
		configuration: {
			triggerType: 'Manual'
			replicaRetryLimit: 1
			manualTriggerConfig: {
				parallelism: 1
				replicaCompletionCount: 1
			}
		}
		template: {
			containers: [
				{
					name: 'mongo-init'
					image: '${acrServer}/mongo:latest'
					resources: {
						cpu: 0.5
						memory: '1.0Gi'
					}
					command: [
						'bash',
						'-lc',
						"sleep 10; echo 'Initializing MongoDB replica set (if needed)...'; mongosh --host mongo --port 27017 --eval 'try { const s = rs.status(); if (s.ok === 1) { print(\"Replica set already initialized\"); quit(0); } } catch (e) { } rs.initiate({ _id: \"${mongoReplicaSetName}\", members: [ { _id: 0, host: \"mongo:27017\" } ] });' || true"
					]
				}
			]
		}
	}
}

// ---------------------------------------------
// Outputs
// ---------------------------------------------
output containerRegistryName string = acr.name
output containerRegistryLoginServer string = acrServer
output environmentId string = cae.id
output rocketchatFqdn string = rocketchat.properties.configuration.ingress.fqdn
