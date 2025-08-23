#!/usr/bin/env bash
set -euo pipefail

# Azure Container Apps deployment script (single region: UK South)
# Usage:
#   GRAFANA_ADMIN_PASSWORD='change-me' ./azure/deploy-aca.sh [rocketchat_tag]

RG="Rocketchat_RG"
LOCATION="uksouth"
DOMAIN="chat.canepro.me"
RC_TAG="${1:-latest}"

require() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: $1 not found"; exit 1; }; }
require az

if ! az account show >/dev/null 2>&1; then
  echo "Please run: az login"
  exit 1
fi

if [[ -z "${GRAFANA_ADMIN_PASSWORD:-}" ]]; then
  echo "ERROR: GRAFANA_ADMIN_PASSWORD env var is required" >&2
  exit 1
fi

echo "==> Creating resource group ($RG)"
az group create --name "$RG" --location "$LOCATION" 1>/dev/null

echo "==> Deploying Bicep template (Rocket.Chat tag: $RC_TAG)"
az deployment group create \
  --resource-group "$RG" \
  --template-file azure/main.bicep \
  --parameters location="$LOCATION" domain="$DOMAIN" grafanaAdminPassword="$GRAFANA_ADMIN_PASSWORD" rocketchatImageTag="$RC_TAG"

echo "==> Discovering ACR"
ACR_NAME=$(az acr list -g "$RG" --query "[0].name" -o tsv)
ACR_SERVER=$(az acr show -n "$ACR_NAME" --query loginServer -o tsv)

echo "==> Importing images into $ACR_NAME"
az acr import -n "$ACR_NAME" --source docker.io/rocketchat/rocket.chat:${RC_TAG#latest}6.5.4 --image rocketchat:$RC_TAG || true
# Import a known good tag if latest; otherwise import requested tag
if [[ "$RC_TAG" != "latest" ]]; then
  az acr import -n "$ACR_NAME" --source docker.io/rocketchat/rocket.chat:$RC_TAG --image rocketchat:$RC_TAG
fi
az acr import -n "$ACR_NAME" --source docker.io/grafana/grafana:12.0.2      --image grafana:latest
az acr import -n "$ACR_NAME" --source docker.io/bitnami/mongodb:7.0         --image mongo:latest
az acr import -n "$ACR_NAME" --source docker.io/prom/prometheus:v3.4.2      --image prometheus:latest
az acr import -n "$ACR_NAME" --source docker.io/nats:2.10-alpine            --image nats:latest
az acr import -n "$ACR_NAME" --source docker.io/bitnami/mongodb-exporter:0.40.0 --image mongodb-exporter:latest
az acr import -n "$ACR_NAME" --source docker.io/natsio/prometheus-nats-exporter:0.14.0 --image nats-exporter:latest

echo "==> Starting Mongo init job"
az containerapp job start --resource-group "$RG" --name mongo-init-replica || true

FQDN=$(az containerapp show -g "$RG" -n rocketchat --query properties.configuration.ingress.fqdn -o tsv)
echo "==> Rocket.Chat FQDN: https://$FQDN"

echo "==> Attempting to add /grafana route to internal app"
set +e
az containerapp ingress route add \
  --resource-group "$RG" \
  --name rocketchat \
  --app-endpoint /grafana \
  --service grafana \
  --service-port 3000 \
  --rewrite-target / >/dev/null 2>&1
RC=$?
set -e
if [[ $RC -ne 0 ]]; then
  echo "WARNING: CLI route command unavailable or failed. If /grafana 404s, update routes via Portal or latest CLI."
fi

echo "==> Done. Configure Cloudflare CNAME: chat.canepro.me -> $FQDN"
