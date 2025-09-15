#!/bin/bash

# Rocket.Chat Observability - TRUE ONE-CLICK DEMO
# This script does everything: setup and start the demo stack

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "🚀 Rocket.Chat Observability - TRUE ONE-CLICK DEMO"
echo "=================================================="
echo ""

# If this script was piped via curl, we might not be in the repo dir
if [ ! -f "compose.yml" ]; then
    print_status "Cloning repository..."
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    git clone https://github.com/Canepro/rocketchat-observability.git rocketchat-observability
    cd rocketchat-observability
    print_success "Repository cloned"
fi

# Detect container runtime
if command -v docker >/dev/null 2>&1; then
    if docker compose version >/dev/null 2>&1; then
        COMPOSE="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        COMPOSE="docker-compose"
    else
        print_error "Docker found but Compose is missing. Install Docker Compose."
        exit 1
    fi
elif command -v podman >/dev/null 2>&1; then
    if podman compose version >/dev/null 2>&1; then
        COMPOSE="podman compose"
    else
        print_error "Podman found but podman compose is missing. Install podman-compose."
        exit 1
    fi
else
    print_error "Neither Docker nor Podman found. Install one and retry."
    exit 1
fi
print_success "Using: $COMPOSE"

# Ensure .env exists
if [ ! -f ".env" ]; then
    print_status "Creating .env from env.example..."
    cp env.example .env
    print_success ".env created"
fi

print_status "Starting Rocket.Chat Observability Demo Stack..."
$COMPOSE -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml -f compose.demo.yml -f compose.nats-exporter.yml up -d

print_success "Demo stack started"

print_status "Waiting for services to become ready..."
sleep 15

print_status "Service status:"
$COMPOSE -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml -f compose.demo.yml -f compose.nats-exporter.yml ps

echo ""
echo "🎉 ROCKET.CHAT OBSERVABILITY DEMO IS READY!"
echo "=========================================="
echo ""
echo "📱 Access your services:"
echo "   • Rocket.Chat: http://localhost:3000"
echo "   • Grafana: http://localhost:5050 (admin/rc-admin)"
echo "   • Prometheus: http://localhost:9090"
echo "   • Traefik Dashboard: http://localhost:8080"
echo ""
echo "🔧 Useful commands:"
echo "   • View logs: $COMPOSE logs -f"
echo "   • Stop stack: $COMPOSE down"
echo "   • Restart: $COMPOSE restart"
echo ""
echo "💡 Demo Features:"
echo "   ✅ No authentication required"
echo "   ✅ Ephemeral ports (no conflicts)"
echo "   ✅ Ready-to-use configuration"
echo "   ✅ All services pre-configured"
echo ""
print_warning "First startup may take a few minutes. Services should become healthy shortly."
echo ""
echo "🚀 Enjoy your Rocket.Chat observability stack!"


