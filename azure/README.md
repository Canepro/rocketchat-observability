# Azure Container Apps Deployment

A production-ready, single-region (UK South) deployment for the Rocket.Chat observability stack.

## What this deploys
- Azure Container Registry (Basic, admin enabled)
- Container Apps Environment + Log Analytics
- Container Apps: rocketchat (external), grafana (internal), mongo, nats, prometheus, mongodb-exporter, nats-exporter
- ACA Job: `mongo-init-replica` (manual trigger)
- Single-ingress model: `/` → Rocket.Chat, `/grafana` → internal Grafana

## Quick start
```bash
# 1) Set a strong password for Grafana admin
export GRAFANA_ADMIN_PASSWORD='change-me'

# 2) Deploy end-to-end (imports images, runs job, adds route)
./azure/deploy-aca.sh
```

## Manual deployment
```bash
# Resource group
az group create -n Rocketchat_RG -l uksouth

# Deploy Bicep
az deployment group create \
  -g Rocketchat_RG \
  --template-file azure/main.bicep \
  --parameters location=uksouth domain=chat.canepro.me grafanaAdminPassword="$GRAFANA_ADMIN_PASSWORD"

# Discover ACR
ACR=$(az acr list -g Rocketchat_RG --query "[0].name" -o tsv)

# Import images
az acr import -n $ACR --source docker.io/rocketchat/rocket.chat:6.5.4 --image rocketchat:latest
az acr import -n $ACR --source docker.io/grafana/grafana:12.0.2      --image grafana:latest
az acr import -n $ACR --source docker.io/bitnami/mongodb:7.0         --image mongo:latest
az acr import -n $ACR --source docker.io/prom/prometheus:v3.4.2      --image prometheus:latest
az acr import -n $ACR --source docker.io/nats:2.10-alpine            --image nats:latest
az acr import -n $ACR --source docker.io/bitnami/mongodb-exporter:0.40.0 --image mongodb-exporter:latest
az acr import -n $ACR --source docker.io/natsio/prometheus-nats-exporter:0.14.0 --image nats-exporter:latest

# Run one-time init
az containerapp job start -g Rocketchat_RG -n mongo-init-replica

# Add route (if supported by your CLI)
az containerapp ingress route add \
  -g Rocketchat_RG \
  -n rocketchat \
  --app-endpoint /grafana \
  --service grafana \
  --service-port 3000 \
  --rewrite-target /
```

## DNS (Cloudflare)
- Create CNAME: `chat.canepro.me` → `rocketchat` FQDN printed by the script/CLI
- SSL/TLS: Full (strict) recommended

## Notes
- Node Exporter is intentionally omitted (not applicable to ACA)
- Grafana admin password is stored as an ACA secret
- Azure Monitor datasource is provisioned via `files/grafana/provisioning/datasources/azure.yml`
