#!/bin/bash

# Environment validation script for Rocket.Chat Observability
# Validates configuration before deployment to catch common issues

set -e

echo "🔍 Validating environment configuration..."

# Check if .env exists
if [[ ! -f .env ]]; then
    echo "❌ ERROR: .env file not found. Copy env.example to .env first."
    echo "   Run: cp env.example .env"
    exit 1
fi

# Source the .env file
source .env

# Validate required variables
REQUIRED_VARS=("DOMAIN" "ROOT_URL")
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo "❌ ERROR: Required variable $var is not set in .env"
        exit 1
    fi
done

# Validate Grafana configuration
if [[ -n "$GRAFANA_DOMAIN" && -n "$GRAFANA_PATH" ]]; then
    echo "⚠️  WARNING: Both GRAFANA_DOMAIN and GRAFANA_PATH are set."
    echo "   This may cause conflicts. Use one or the other:"
    echo "   - For subpath: Set GRAFANA_PATH=/grafana, leave GRAFANA_DOMAIN empty"
    echo "   - For subdomain: Set GRAFANA_DOMAIN=grafana.yourdomain.com, leave GRAFANA_PATH empty"
fi

if [[ -z "$GRAFANA_DOMAIN" && -z "$GRAFANA_PATH" ]]; then
    echo "❌ ERROR: Neither GRAFANA_DOMAIN nor GRAFANA_PATH is set."
    echo "   Set GRAFANA_PATH=/grafana for most deployments."
    exit 1
fi

# Validate URLs format
if [[ ! "$ROOT_URL" =~ ^https?:// ]]; then
    echo "❌ ERROR: ROOT_URL must start with http:// or https://"
    exit 1
fi

# Check for common misconfigurations
if [[ "$GRAFANA_PATH" == "/grafana/grafana" ]]; then
    echo "❌ ERROR: GRAFANA_PATH has double path (/grafana/grafana)"
    echo "   Fix: Set GRAFANA_PATH=/grafana"
    exit 1
fi

# Validate container runtime availability
if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
        echo "✅ Docker runtime detected and accessible"
    else
        echo "❌ ERROR: Docker is installed but not accessible"
        echo "   This is usually a permissions issue. Try one of these fixes:"
        echo "   1. Add your user to the docker group:"
        echo "      sudo usermod -aG docker $USER"
        echo "      newgrp docker  # or logout/login"
        echo "   2. Use sudo:"
        echo "      sudo make demo-up"
        echo "   3. Check if Docker daemon is running:"
        echo "      sudo systemctl status docker"
        exit 1
    fi
elif command -v podman >/dev/null 2>&1; then
    if podman info >/dev/null 2>&1; then
        echo "✅ Podman runtime detected and accessible"
    else
        echo "❌ ERROR: Podman is installed but not accessible"
        exit 1
    fi
else
    echo "❌ ERROR: Neither Docker nor Podman is available"
    exit 1
fi

echo "✅ Environment validation passed!"
echo ""
echo "🚀 Configuration summary:"
echo "   Domain: $DOMAIN"
echo "   Rocket.Chat: $ROOT_URL"
if [[ -n "$GRAFANA_DOMAIN" ]]; then
    echo "   Grafana: http://$GRAFANA_DOMAIN (subdomain mode)"
else
    echo "   Grafana: http://$DOMAIN$GRAFANA_PATH (subpath mode)"
fi
echo ""
