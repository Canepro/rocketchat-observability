#!/bin/bash

# Rocket.Chat Observability Stack - One-Click Startup Script
# This script provides a simple way to get started with minimal configuration

set -euo pipefail

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if we're in the right directory
if [ ! -f "compose.yml" ]; then
    print_error "Please run this script from the rocketchat-observability directory"
    exit 1
fi

source scripts/runtime-detect.sh

# Setup environment file
setup_env() {
    if [ ! -f ".env" ]; then
        print_status "Creating .env file from template..."
        cp .env.example .env
        print_success ".env file created with default settings"
        print_warning "You can edit .env to customize ports, passwords, etc."
    else
        print_status ".env file already exists"
    fi
}

main() {
    echo "🚀 Rocket.Chat Observability Stack - One-Click Startup"
    echo "=================================================="
    echo ""

    scripts/check-requirements.sh
    setup_env
    make demo-up
}

case "${1:-}" in
    minimal)
        print_status "Starting minimal stack (Rocket.Chat + Traefik only)..."
        scripts/check-requirements.sh
        setup_env
        $COMPOSE --env-file .env -f compose.traefik.yml -f compose.yml up -d
        print_success "Minimal stack started!"
        ;;
    help|-h|--help)
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  (no args)  - Start full observability stack"
        echo "  minimal    - Start only Rocket.Chat + Traefik"
        echo "  help       - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0          # Start everything"
        echo "  $0 minimal  # Start minimal setup"
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
