#!/bin/bash

# Rocket.Chat Observability - TRUE ONE-CLICK PRODUCTION
# Interactive setup script for production deployment

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

echo "🚀 Rocket.Chat Observability - TRUE ONE-CLICK PRODUCTION"
echo "======================================================="
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

echo ""
echo "🔧 Production Configuration"
echo "=========================="
echo ""

read -p "Enter your domain name (e.g., chat.yourdomain.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    print_error "Domain name is required for production deployment"
    exit 1
fi

read -p "Enter your email for SSL certificates: " EMAIL
if [ -z "$EMAIL" ]; then
    print_error "Email is required for Let's Encrypt certificates"
    exit 1
fi

read -s -p "Enter Grafana admin password: " GRAFANA_PASSWORD
echo ""
if [ -z "$GRAFANA_PASSWORD" ]; then
    GRAFANA_PASSWORD="rc-admin-prod"
    print_warning "Using default Grafana password: rc-admin-prod"
fi

read -s -p "Enter MongoDB root password: " MONGO_PASSWORD
echo ""
if [ -z "$MONGO_PASSWORD" ]; then
    MONGO_PASSWORD=$(openssl rand -base64 32)
    print_warning "Generated MongoDB password automatically"
fi

print_status "Setting up production environment..."
cp env.example .env

sed -i "s/DOMAIN=.*/DOMAIN=$DOMAIN/" .env
sed -i "s|ROOT_URL=.*|ROOT_URL=https://$DOMAIN|" .env
sed -i "s/GRAFANA_ADMIN_PASSWORD=.*/GRAFANA_ADMIN_PASSWORD=$GRAFANA_PASSWORD/" .env
sed -i "s/MONGODB_ENABLE_AUTHENTICATION=.*/MONGODB_ENABLE_AUTHENTICATION=true/" .env
sed -i "s/MONGODB_ROOT_PASSWORD=.*/MONGODB_ROOT_PASSWORD=$MONGO_PASSWORD/" .env
sed -i "s/TRAEFIK_PROTOCOL=.*/TRAEFIK_PROTOCOL=https/" .env
sed -i "s/LETSENCRYPT_ENABLED=.*/LETSENCRYPT_ENABLED=true/" .env
sed -i "s/LETSENCRYPT_EMAIL=.*/LETSENCRYPT_EMAIL=$EMAIL/" .env

print_success "Production environment configured"

echo ""
print_status "Ensure ports 80, 443, 3000, 5050, 9090, 8080 are open (inbound)."
echo "See docs/DEPLOYMENT_GUIDE.md for details."
echo ""
read -p "Press Enter to continue with deployment..." _

print_status "Starting Rocket.Chat Observability Production Stack..."
$COMPOSE -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml -f compose.prod.yml -f compose.nats-exporter.yml up -d

print_success "Production stack started"

print_status "Waiting for services to become ready..."
sleep 20

print_status "Service status:"
$COMPOSE -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml -f compose.prod.yml -f compose.nats-exporter.yml ps

echo ""
echo "🎉 ROCKET.CHAT OBSERVABILITY PRODUCTION IS READY!"
echo "================================================"
echo ""
echo "📱 Access your services:"
echo "   • Rocket.Chat: https://$DOMAIN"
echo "   • Grafana: https://$DOMAIN:5050 (admin/$GRAFANA_PASSWORD)"
echo "   • Prometheus: https://$DOMAIN:9090"
echo "   • Traefik Dashboard: https://$DOMAIN:8080"
echo ""
echo "🔧 Useful commands:"
echo "   • View logs: $COMPOSE logs -f"
echo "   • Stop stack: $COMPOSE down"
echo "   • Restart: $COMPOSE restart"
echo ""
echo "💡 Production Features:"
echo "   ✅ SSL/TLS certificates (Let's Encrypt)"
echo "   ✅ MongoDB authentication enabled"
echo "   ✅ Secure passwords configured"
echo "   ✅ Production-ready configuration"
echo ""
print_warning "First startup may take a few minutes. SSL certificates will be generated automatically."
echo ""
echo "🚀 Your production Rocket.Chat observability stack is ready!"


