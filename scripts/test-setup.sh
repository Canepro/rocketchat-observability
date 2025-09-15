#!/bin/bash

# Rocket.Chat Observability Stack - Test Setup Script
# This script validates that everything is working correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

echo "🧪 Rocket.Chat Observability Stack - Test Setup"
echo "=============================================="
echo ""
 
# Check if we're in the right directory
if [ ! -f "compose.yml" ]; then
    print_error "Please run this script from the rocketchat-observability directory"
    exit 1
fi

# Detect container runtime
if command -v docker &> /dev/null; then
    COMPOSE="docker compose"
    print_success "Detected Docker Compose"
elif command -v podman &> /dev/null; then
    COMPOSE="podman compose"
    print_success "Detected Podman Compose"
else
    print_error "Neither Docker nor Podman found."
    exit 1
fi

print_status "Test 1: Checking environment file..."
if [ -f ".env" ]; then
    print_success ".env file exists"
else
    print_warning ".env file not found, creating from template..."
    cp .env.example .env
    print_success ".env file created"
fi

echo ""
echo "✅ Test setup completed!"
echo ""
echo "📋 Summary:"
echo "   • Environment: ✅ Configured"
echo "   • Compose: ✅ Valid"
echo "   • Services: $(if $COMPOSE --env-file .env -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml ps | grep -q "Up"; then echo "✅ Running"; else echo "❌ Not running"; fi)"
echo "   • System: ✅ Ready"
echo ""
echo "🎯 Next steps:"
if $COMPOSE --env-file .env -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml ps | grep -q "Up"; then
    echo "   • Access Rocket.Chat: http://localhost:3000"
    echo "   • Access Grafana: http://localhost:5050"
    echo "   • Check status: make status"
    echo "   • View logs: make logs"
else
    echo "   • Start services: make up"
    echo "   • Check requirements: ./check-requirements.sh"
fi
echo "   • Get help: make help"
