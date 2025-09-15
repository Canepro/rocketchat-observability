# Rocket.Chat Kubernetes Deployment Guide

## Overview

This deployment creates a monolithic Rocket.Chat setup with 2 pods running on your Azure VM (52.183.221.89), designed to replicate your customer's production environment for testing purposes.

## Azure VM Setup (Fresh Installation)

Since your Azure VM is freshly installed, you'll need to set up the prerequisites:

### 1. Install Docker
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install docker-compose-plugin -y

# Logout and login again for group changes
```

### 2. Install Kubernetes (k3s - lightweight)
```bash
# Install k3s (lightweight Kubernetes)
curl -sfL https://get.k3s.io | sh -

# Check status
sudo systemctl status k3s

# Configure kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Test connection
kubectl cluster-info
```

### 3. Install Helm v3
```bash
# Download and install Helm
curl https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz -o helm.tar.gz
tar -zxvf helm.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm

# Verify installation
helm version
```

### 4. Install Nginx Ingress Controller
```bash
# Add nginx helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install nginx ingress
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --set controller.publishService.enabled=true \
  --set controller.service.externalIPs="{52.183.221.89}"
```

### 5. Verify Installation
```bash
# Check all components
kubectl get nodes
kubectl get pods -n kube-system
kubectl get svc -n ingress-nginx

# Test ingress
curl http://52.183.221.89
```

## Architecture

```
Internet → Nginx Ingress → Rocket.Chat Service → Rocket.Chat Pods (2 replicas)
                                       ↓
Internal MongoDB Service → MongoDB Pod (replica set)
```

### Components

- **Rocket.Chat Pods**: 2 replicas with monolithic deployment (microservices disabled)
- **MongoDB Pod**: Single replica with replica set configuration
- **MongoDB Init Job**: Initializes the replica set after MongoDB starts
- **Nginx Ingress**: Load balancer with hash-based routing
- **ConfigMap**: Environment variables and configuration
- **Service**: ClusterIP for internal load balancing (both Rocket.Chat and MongoDB)
- **Pod Disruption Budget**: Ensures high availability during updates

## Prerequisites

### 1. Kubernetes Cluster
- Running on Azure VM with public IP: `52.183.221.89`
- `kubectl` configured and connected to the cluster
- Nginx Ingress Controller installed in the cluster

### 2. MongoDB
- **Internal MongoDB**: Automatically deployed alongside Rocket.Chat
- **Replica Set**: Configured as `rs0` for Rocket.Chat compatibility
- **Authentication**: Username: `rocketchat`, Password: `rocketchat123`
- **Database**: `rocketchat`

### 3. Nginx Ingress Controller
Install nginx ingress controller if not already present:

```bash
# Using Helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --set controller.publishService.enabled=true
```

## Quick Deployment

### Option 1: Using the Deployment Script (Recommended)

```bash
cd k8s
./deploy.sh deploy
```

### Option 2: Manual Deployment

```bash
cd k8s

# Deploy all components
kubectl apply -f serviceaccount.yaml
kubectl apply -f configmap.yaml
kubectl apply -f poddisruptionbudget.yaml
kubectl apply -f rocketchat-deployment.yaml
kubectl apply -f rocketchat-service.yaml
kubectl apply -f nginx-ingress.yaml

# Wait for deployment
kubectl wait --for=condition=available --timeout=300s deployment/rocketchat
```

## Configuration

### MongoDB Connection

Update the MongoDB connection details in `configmap.yaml`:

```yaml
data:
  MONGO_URL: "mongodb://your-mongodb-host:27017/rocketchat"
  MONGO_OPLOG_URL: "mongodb://your-mongodb-host:27017/local"
```

For local MongoDB on the same machine:
```yaml
MONGO_URL: "mongodb://host.docker.internal:27017/rocketchat"
MONGO_OPLOG_URL: "mongodb://host.docker.internal:27017/local"
```

### Rocket.Chat Configuration

Customize Rocket.Chat settings in `configmap.yaml`:

```yaml
data:
  ROOT_URL: "http://52.183.221.89"  # Your VM public IP
  ADMIN_USERNAME: "admin"
  ADMIN_PASS: "changeme123"
  ADMIN_EMAIL: "admin@example.com"
```

## Access Information

### Web Interface
- **URL**: http://52.183.221.89
- **Admin Username**: admin (or create new admin user)
- **Admin Password**: changeme123

### Kubernetes Access
```bash
# Check pod status
kubectl get pods -l app=rocketchat

# View logs
kubectl logs -l app=rocketchat --tail=100

# Get service details
kubectl get svc rocketchat-service

# Get ingress details
kubectl get ingress rocketchat-ingress
```

## Scaling

### Change Number of Pods

Edit `rocketchat-deployment.yaml`:
```yaml
spec:
  replicas: 3  # Change from 2 to 3
```

Apply the change:
```bash
kubectl apply -f rocketchat-deployment.yaml
```

### Resource Limits

Current resource allocation (from your values.yaml):
- **Requests**: 1Gi memory, 500m CPU
- **Limits**: 2Gi memory, 1000m CPU

Modify in `rocketchat-deployment.yaml` under `resources:` section.

## Load Balancing

### Nginx Ingress Features
- **Hash-based routing**: `nginx.ingress.kubernetes.io/upstream-hash-by: "$$request_uri$$host"`
- **WebSocket support**: Automatic connection upgrades
- **Large file uploads**: `proxy-body-size: "0"`
- **Sticky sessions**: Based on request URI and host

### External Load Balancing

For production-like setup with external nginx, use the configuration in `external-nginx-config` as a reference.

## Monitoring

### Health Checks
- **Liveness Probe**: `/health` endpoint, checks every 10s
- **Readiness Probe**: `/health` endpoint, initial delay 10s

### Pod Disruption Budget
- **Min Available**: 1 pod always available
- **Selector**: `app=rocketchat, component=chat`

## Backup and Recovery

### Database Backup
Since MongoDB is external, handle backups separately:
```bash
# Local MongoDB backup
mongodump --db rocketchat --out /path/to/backup

# Restore
mongorestore --db rocketchat /path/to/backup/rocketchat
```

### Application Data
Rocket.Chat data is stored in MongoDB. No persistent volumes are used in this deployment.

## Troubleshooting

See `troubleshooting.md` for detailed troubleshooting steps.

## Cleanup

### Using the Script
```bash
cd k8s
./deploy.sh cleanup
```

### Manual Cleanup
```bash
kubectl delete ingress rocketchat-ingress
kubectl delete svc rocketchat-service
kubectl delete deployment rocketchat
kubectl delete pdb rocketchat-pdb
kubectl delete configmap rocketchat-config
kubectl delete sa rocketchat-sa
```

## Security Considerations

### Current Setup
- **Pod Security**: Non-root user (999), read-only root filesystem
- **Network**: ClusterIP service, ingress-based external access
- **Secrets**: Configuration in ConfigMap (consider using Secrets for production)

### Production Recommendations
1. Use Kubernetes Secrets for sensitive data
2. Enable TLS/SSL certificates
3. Configure proper RBAC
4. Use network policies
5. Enable pod security standards

## File Structure

```
k8s/
├── configmap.yaml           # Environment variables and configuration
├── rocketchat-deployment.yaml # Main Rocket.Chat deployment (2 pods)
├── rocketchat-service.yaml   # ClusterIP service for load balancing
├── mongodb-deployment.yaml   # MongoDB deployment with replica set
├── mongodb-init-job.yaml     # MongoDB replica set initialization
├── nginx-ingress.yaml        # Nginx ingress configuration
├── serviceaccount.yaml       # ServiceAccount for pods
├── poddisruptionbudget.yaml  # High availability configuration
├── external-nginx-config     # Reference nginx config for external LB
├── deploy.sh                 # Deployment and management script
├── deployment.md            # This documentation
├── troubleshooting.md       # Troubleshooting guide
└── helm/                    # Alternative Helm deployment
    └── rocketchat/
        ├── Chart.yaml
        ├── values.yaml
        ├── README.md
        └── templates/
```

## Next Steps

1. **Set up Azure VM**: Follow the Azure VM Setup section above
2. **Deploy**: Run `./deploy.sh deploy`
3. **Verify**: Check that all pods are running with `./deploy.sh status`
4. **Access**: Open http://52.183.221.89 in your browser
5. **Configure**: Create admin user and set up Rocket.Chat
6. **Test**: Verify load balancing by checking pod logs during usage

## Official Rocket.Chat Helm Chart

As an alternative, you can also use the official Rocket.Chat Helm chart:

```bash
# Add Rocket.Chat helm repo
helm repo add rocketchat https://rocketchat.github.io/helm-charts
helm repo update

# Install with your custom values
helm install rocketchat rocketchat/rocketchat \
  --set mongodb.enabled=true \
  --set replicaCount=2 \
  --set microservices.enabled=false \
  --set host=52.183.221.89
```

For issues, refer to `troubleshooting.md` or check the logs with `./deploy.sh logs`.
