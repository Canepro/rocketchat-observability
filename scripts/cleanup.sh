#!/bin/bash

# Rocket.Chat Observability Stack - Cleanup Script
# This script helps with maintenance and cleanup tasks

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

echo "🧹 Rocket.Chat Observability Stack - Cleanup & Maintenance"
echo "========================================================="
echo ""

# Detect container runtime
if command -v docker &> /dev/null; then
    COMPOSE="docker compose"
elif command -v podman &> /dev/null; then
    COMPOSE="podman compose"
else
    print_error "Neither Docker nor Podman found."
    exit 1
fi

# Function to cleanup containers and volumes
cleanup_containers() {
    print_status "Cleaning up containers and volumes..."
    $COMPOSE --env-file .env -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml down --remove-orphans --volumes
    print_success "Containers and volumes cleaned up!"
}

# Function to cleanup images
cleanup_images() {
    print_status "Cleaning up unused images..."
    if command -v docker &> /dev/null; then
        docker image prune -f
        docker system prune -f
    elif command -v podman &> /dev/null; then
        podman image prune -f
        podman system prune -f
    fi
    print_success "Unused images cleaned up!"
}

# Function to cleanup networks
cleanup_networks() {
    print_status "Cleaning up unused networks..."
    if command -v docker &> /dev/null; then
        docker network prune -f
    elif command -v podman &> /dev/null; then
        podman network prune -f
    fi
    print_success "Unused networks cleaned up!"
}

# Function to show disk usage
show_disk_usage() {
    print_status "Current disk usage:"
    if command -v docker &> /dev/null; then
        docker system df
    elif command -v podman &> /dev/null; then
        podman system df
    fi
}

# Function to update images
update_images() {
    print_status "Pulling latest images..."
    $COMPOSE --env-file .env -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml pull
    print_success "Images updated!"
}

# Function to show current versions
show_versions() {
    print_status "Current image versions:"
    if command -v docker &> /dev/null; then
        docker images | grep -E "(rocketchat|mongodb|prometheus|grafana|traefik|nats)"
    elif command -v podman &> /dev/null; then
        podman images | grep -E "(rocketchat|mongodb|prometheus|grafana|traefik|nats)"
    fi
}

# Main menu
case "${1:-}" in
    "containers")
        cleanup_containers
        ;;
    "images")
        cleanup_images
        ;;
    "networks")
        cleanup_networks
        ;;
    "all")
        print_warning "This will remove ALL containers, images, and networks!"
        read -p "Are you sure? (y/N): " confirm
        if [ "$confirm" = "y" ]; then
            cleanup_containers
            cleanup_images
            cleanup_networks
            print_success "Complete cleanup finished!"
        else
            print_status "Cleanup cancelled."
        fi
        ;;
    "update")
        update_images
        ;;
    "versions")
        show_versions
        ;;
    "disk")
        show_disk_usage
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  containers  - Clean up containers and volumes"
        echo "  images      - Clean up unused images"
        echo "  networks    - Clean up unused networks"
        echo "  all         - Complete cleanup (containers + images + networks)"
        echo "  update      - Pull latest images"
        echo "  versions    - Show current image versions"
        echo "  disk        - Show disk usage"
        echo "  help        - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 containers  # Clean up containers only"
        echo "  $0 all         # Complete cleanup"
        echo "  $0 update      # Update images"
        ;;
    "")
        echo "Please specify an option. Use '$0 help' for usage information."
        exit 1
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
