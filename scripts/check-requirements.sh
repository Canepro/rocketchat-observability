#!/bin/bash

# Rocket.Chat Observability Stack - Requirements Checker
# This script validates your system before deployment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/runtime-detect.sh"

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

echo "🔍 Rocket.Chat Observability Stack - System Requirements Check"
echo "============================================================="
echo ""

# Check container runtime
print_status "Checking container runtime..."
RUNTIME_VERSION=$($RUNTIME --version | head -n1)
print_success "$RUNTIME found: $RUNTIME_VERSION"

# Check compose
print_status "Checking compose support..."
if COMPOSE_VERSION=$($COMPOSE version --short 2>/dev/null); then
    print_success "Compose found: $COMPOSE_VERSION"
else
    print_error "Compose command not found. Please install Docker/Podman compose plugin."
    exit 1
fi

# Check system resources
print_status "Checking system resources..."

# Memory check
if command -v free &> /dev/null; then
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$MEMORY_GB" -ge 4 ]; then
        print_success "Memory: ${MEMORY_GB}GB available (4GB+ recommended)"
    elif [ "$MEMORY_GB" -ge 2 ]; then
        print_warning "Memory: ${MEMORY_GB}GB available (4GB+ recommended, but should work)"
    else
        print_error "Memory: ${MEMORY_GB}GB available (4GB+ recommended)"
        echo "The stack may not run properly with less than 4GB RAM."
    fi
else
    print_warning "Could not check memory (free command not available)"
fi

# Disk space check
if command -v df &> /dev/null; then
    DISK_GB=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$DISK_GB" -ge 10 ]; then
        print_success "Disk space: ${DISK_GB}GB available (10GB+ recommended)"
    elif [ "$DISK_GB" -ge 5 ]; then
        print_warning "Disk space: ${DISK_GB}GB available (10GB+ recommended, but should work)"
    else
        print_error "Disk space: ${DISK_GB}GB available (10GB+ recommended)"
        echo "Please free up some disk space before proceeding."
    fi
else
    print_warning "Could not check disk space (df command not available)"
fi

# Check ports
print_status "Checking required ports..."

PORTS_TO_CHECK=(3000 5050 9000 8080 80 443)
for port in "${PORTS_TO_CHECK[@]}"; do
    if command -v netstat &> /dev/null; then
        if netstat -tuln | grep -q ":$port "; then
            print_warning "Port $port is already in use"
        else
            print_success "Port $port is available"
        fi
    elif command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":$port "; then
            print_warning "Port $port is already in use"
        else
            print_success "Port $port is available"
        fi
    else
        print_warning "Could not check port $port (netstat/ss not available)"
    fi
done

# Check if we're in the right directory
print_status "Checking project files..."

if [ -f "compose.yml" ] && [ -f ".env.example" ]; then
    print_success "Project files found"
else
    print_error "Please run this script from the rocketchat-observability directory"
    exit 1
fi

echo ""
echo "✅ Requirements check completed!"
echo ""
echo "🎯 Next steps:"
echo "   • Run './start.sh' to deploy the stack"
echo "   • Or run 'make demo-up' for Makefile-based deployment"
echo ""
echo "📚 For more information:"
echo "   • Run 'make help' for all available commands"
echo "   • Check README.md for detailed documentation"
