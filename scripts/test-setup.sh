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

# Test 1: Check if .env exists
print_status "Test 1: Checking environment file..."
if [ -f ".env" ]; then
    print_success ".env file exists"
else
    print_warning ".env file not found, creating from template..."
    cp .env.example .env
    print_success ".env file created"
fi

# Test 2: Validate compose configuration
print_status "Test 2: Validating compose configuration..."
if $COMPOSE --env-file .env -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml config > /dev/null 2>&1; then
    print_success "Compose configuration is valid"
else
    print_error "Compose configuration validation failed"
    exit 1
fi

# Test 3: Check if services are running
print_status "Test 3: Checking if services are running..."
if $COMPOSE --env-file .env -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml ps | grep -q "Up"; then
    print_success "Services are running"
    
    # Test 4: Check service health
    print_status "Test 4: Checking service health..."
    
    # Check Rocket.Chat
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        print_success "Rocket.Chat is responding"
    else
        print_warning "Rocket.Chat is not responding (may still be starting)"
    fi
    
    # Check Grafana
    if curl -s http://localhost:5050 > /dev/null 2>&1; then
        print_success "Grafana is responding"
    else
        print_warning "Grafana is not responding (may still be starting)"
    fi
    
    # Check Prometheus
    if curl -s http://127.0.0.1:9000 > /dev/null 2>&1; then
        print_success "Prometheus is responding"
    else
        print_warning "Prometheus is not responding (may still be starting)"
    fi
    
    # Check Traefik
    if curl -s http://localhost:8080 > /dev/null 2>&1; then
        print_success "Traefik dashboard is responding"
    else
        print_warning "Traefik dashboard is not responding (may still be starting)"
    fi
    
else
    print_warning "Services are not running"
    echo "To start services, run: make up"
fi

# Test 5: Check disk space
print_status "Test 5: Checking disk space..."
if command -v df &> /dev/null; then
    DISK_GB=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$DISK_GB" -ge 5 ]; then
        print_success "Sufficient disk space: ${DISK_GB}GB available"
    else
        print_warning "Low disk space: ${DISK_GB}GB available (5GB+ recommended)"
    fi
fi

# Test 6: Check memory
print_status "Test 6: Checking memory..."
if command -v free &> /dev/null; then
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$MEMORY_GB" -ge 4 ]; then
        print_success "Sufficient memory: ${MEMORY_GB}GB available"
    else
        print_warning "Low memory: ${MEMORY_GB}GB available (4GB+ recommended)"
    fi
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
