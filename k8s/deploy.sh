#!/bin/bash

# Rocket.Chat Kubernetes Deployment Script
# Deploys Rocket.Chat with 2 pods in monolithic mode to Azure VM

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
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

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check if kubectl is installed and configured
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi

    # Check if we can connect to the cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi

    # Check if namespace exists
    if ! kubectl get namespace default &> /dev/null; then
        print_error "Default namespace not found."
        exit 1
    fi

    print_success "Prerequisites check passed"
}

# Deploy components
deploy_components() {
    print_status "Deploying Rocket.Chat Kubernetes components..."

    # Create ServiceAccount
    print_status "Creating ServiceAccount..."
    kubectl apply -f serviceaccount.yaml

    # Deploy MongoDB
    print_status "Deploying MongoDB database..."
    kubectl apply -f mongodb-deployment.yaml

    # Wait for MongoDB to be ready
    print_status "Waiting for MongoDB to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/rocketchat-mongodb

    # Initialize MongoDB replica set
    print_status "Initializing MongoDB replica set..."
    kubectl apply -f mongodb-init-job.yaml

    # Wait for init job to complete
    kubectl wait --for=condition=complete --timeout=300s job/rocketchat-mongodb-init

    # Create ConfigMap
    print_status "Creating ConfigMap..."
    kubectl apply -f configmap.yaml

    # Create Pod Disruption Budget
    print_status "Creating Pod Disruption Budget..."
    kubectl apply -f poddisruptionbudget.yaml

    # Deploy Rocket.Chat
    print_status "Deploying Rocket.Chat application..."
    kubectl apply -f rocketchat-deployment.yaml

    # Create Service
    print_status "Creating Service for load balancing..."
    kubectl apply -f rocketchat-service.yaml

    # Create Ingress
    print_status "Creating Nginx Ingress..."
    kubectl apply -f nginx-ingress.yaml

    print_success "All components deployed successfully"
}

# Wait for deployment to be ready
wait_for_deployment() {
    print_status "Waiting for Rocket.Chat deployment to be ready..."

    # Wait for deployment to be available
    kubectl wait --for=condition=available --timeout=300s deployment/rocketchat

    # Wait for pods to be ready
    kubectl wait --for=condition=ready pod -l app=rocketchat --timeout=300s

    print_success "Deployment is ready!"
}

# Show deployment status
show_status() {
    echo ""
    print_success "Rocket.Chat Deployment Status:"
    echo "=================================="

    # Show pods
    echo ""
    echo "Pods:"
    kubectl get pods -l app=rocketchat
    kubectl get pods -l app=mongodb

    # Show services
    echo ""
    echo "Services:"
    kubectl get svc -l app=rocketchat
    kubectl get svc -l app=mongodb

    # Show ingress
    echo ""
    echo "Ingress:"
    kubectl get ingress rocketchat-ingress

    # Show deployments
    echo ""
    echo "Deployments:"
    kubectl get deployment rocketchat
    kubectl get deployment rocketchat-mongodb

    # Show jobs
    echo ""
    echo "Jobs:"
    kubectl get jobs

    # Access information
    echo ""
    print_success "Access Information:"
    echo "===================="
    echo "Rocket.Chat URL: http://52.183.221.89"
    echo "Admin Username: admin"
    echo "Admin Password: changeme123"
    echo ""
    echo "MongoDB Connection: mongodb://host.docker.internal:27017/rocketchat"
    echo ""
    print_warning "Important: Make sure your local MongoDB is running and accessible"
    print_warning "Update the MONGO_URL and MONGO_OPLOG_URL in configmap.yaml if needed"
}

# Main deployment function
main() {
    echo "🚀 Rocket.Chat Kubernetes Deployment"
    echo "===================================="
    echo ""

    check_prerequisites
    deploy_components
    wait_for_deployment
    show_status

    echo ""
    print_success "Deployment completed successfully! 🎉"
    echo ""
    print_status "Next steps:"
    echo "1. Ensure your local MongoDB is running"
    echo "2. Access Rocket.Chat at http://52.183.221.89"
    echo "3. Create your admin user or use the default credentials"
    echo "4. Check the deployment documentation for troubleshooting"
}

# Handle command line arguments
case "${1:-}" in
    "deploy")
        main
        ;;
    "status")
        show_status
        ;;
    "cleanup")
        print_warning "Cleaning up Rocket.Chat deployment..."
        kubectl delete -f nginx-ingress.yaml --ignore-not-found=true
        kubectl delete -f rocketchat-service.yaml --ignore-not-found=true
        kubectl delete -f mongodb-deployment.yaml --ignore-not-found=true
        kubectl delete -f mongodb-init-job.yaml --ignore-not-found=true
        kubectl delete -f rocketchat-deployment.yaml --ignore-not-found=true
        kubectl delete -f poddisruptionbudget.yaml --ignore-not-found=true
        kubectl delete -f configmap.yaml --ignore-not-found=true
        kubectl delete -f serviceaccount.yaml --ignore-not-found=true
        print_success "Cleanup completed"
        ;;
    "logs")
        print_status "Showing Rocket.Chat logs..."
        kubectl logs -l app=rocketchat --tail=100 -f
        ;;
    *)
        echo "Usage: $0 {deploy|status|cleanup|logs}"
        echo ""
        echo "Commands:"
        echo "  deploy  - Deploy Rocket.Chat to Kubernetes"
        echo "  status  - Show deployment status"
        echo "  cleanup - Remove all Rocket.Chat components"
        echo "  logs    - Show Rocket.Chat pod logs"
        exit 1
        ;;
esac
