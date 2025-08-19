#!/bin/bash

# Rocket.Chat Observability Stack - One-Click Startup Script
# This script provides a simple way to get started with minimal configuration

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

# Check if we're in the right directory
if [ ! -f "compose.yml" ]; then
    print_error "Please run this script from the rocketchat-observability directory"
    exit 1
fi

# Detect container runtime
detect_runtime() {
    if command -v docker &> /dev/null; then
        # Check if docker compose is available
        if docker compose version &> /dev/null; then
            COMPOSE="docker compose"
            print_success "Detected Docker Compose"
        elif command -v docker-compose &> /dev/null; then
            COMPOSE="docker-compose"
            print_success "Detected Docker Compose (legacy)"
        else
            print_error "Docker found but docker compose is not available."
            print_error "Please install Docker Compose or update Docker Desktop."
            exit 1
        fi
    elif command -v podman &> /dev/null; then
        if podman compose version &> /dev/null; then
            COMPOSE="podman compose"
            print_success "Detected Podman Compose"
        else
            print_error "Podman found but podman compose is not available."
            print_error "Please install podman-compose."
            exit 1
        fi
    else
        print_error "Neither Docker nor Podman found. Please install one of them."
        exit 1
    fi
}

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

# Check system requirements
check_requirements() {
    print_status "Checking system requirements..."
    
    # Check available memory (at least 4GB recommended)
    if command -v free &> /dev/null; then
        MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
        if [ "$MEMORY_GB" -lt 4 ]; then
            print_warning "Less than 4GB RAM detected. Performance may be slow."
        else
            print_success "Memory: ${MEMORY_GB}GB available"
        fi
    fi
    
    # Check available disk space (at least 5GB recommended)
    if command -v df &> /dev/null; then
        DISK_GB=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
        if [ "$DISK_GB" -lt 5 ]; then
            print_warning "Less than 5GB free disk space. Consider freeing up space."
        else
            print_success "Disk space: ${DISK_GB}GB available"
        fi
    fi
}

# Start the stack
start_stack() {
    print_status "Starting Rocket.Chat Observability Stack..."
    
    # Validate configuration first
    print_status "Validating configuration..."
    $COMPOSE --env-file .env -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml config > /dev/null
    
    # Start services
    $COMPOSE --env-file .env -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml up -d
    
    print_success "Stack started successfully!"
}

# Show service information
show_info() {
    echo ""
    echo "🎉 Rocket.Chat Observability Stack is now running!"
    echo ""
    echo "📱 Access your services:"
    echo "   • Rocket.Chat: http://localhost:3000"
    echo "   • Grafana: http://localhost:5050"
    echo "     - Username: admin"
    echo "     - Password: rc-admin"
    echo "   • Prometheus: http://127.0.0.1:9000"
    echo "   • Traefik Dashboard: http://localhost:8080"
    echo ""
    echo "🔧 Useful commands:"
    echo "   • View logs: make logs"
    echo "   • Check status: make status"
    echo "   • Stop stack: make down"
    echo "   • Full help: make help"
    echo ""
    print_warning "First startup may take a few minutes. Services will be ready when all containers show 'healthy' status."
}

# Main execution
main() {
    echo "🚀 Rocket.Chat Observability Stack - One-Click Startup"
    echo "=================================================="
    echo ""
    
    detect_runtime
    check_requirements
    setup_env
    start_stack
    show_info
}

# Handle script arguments
case "${1:-}" in
    "minimal")
        print_status "Starting minimal stack (Rocket.Chat + Traefik only)..."
        setup_env
        $COMPOSE --env-file .env -f compose.traefik.yml -f compose.yml up -d
        print_success "Minimal stack started!"
        echo "🌐 Rocket.Chat: http://localhost:3000"
        ;;
    "help"|"-h"|"--help")
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
