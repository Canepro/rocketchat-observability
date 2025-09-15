# Rocket.Chat Kubernetes Deployment Guide

## 🎉 DEPLOYMENT SUCCESSFUL

This deployment creates a monolithic Rocket.Chat setup running on your Azure VM (52.183.221.89), designed to replicate your customer's production environment for testing purposes.

### 🌐 Access Information
- **URL**: http://52.183.221.89
- **Status**: ✅ FULLY OPERATIONAL (2 pods)
- **Ingress**: Nginx on port 80 (Traefik disabled)
- **Admin**: Existing admin user present; environment ADMIN_PASS may be ignored

## Azure VM Setup (Fresh Installation) ✅ COMPLETED

Since your Azure VM is freshly installed, you'll need to set up the prerequisites:

### 1. Install Docker ✅ COMPLETED
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

### 2. Install Kubernetes (k3s - lightweight) ✅ COMPLETED
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

### 3. Install Helm v3 ✅ COMPLETED
```bash
# ✅ SUCCESSFUL METHOD USED:
sudo snap remove helm
cd /tmp
wget https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz
tar -zxvf helm-v3.13.0-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
sudo chmod +x /usr/local/bin/helm
helm version  # Shows: version.BuildInfo{Version:"v3.13.0", ...}
```

**Alternative methods (if needed):**
```bash
# Snap method (may cause segfaults)
sudo snap install helm --classic

# Apt repository method
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt update && sudo apt install helm
```

### 4. Install Nginx Ingress Controller ✅ COMPLETED
```bash
# ✅ SUCCESSFUL INSTALLATION:
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install nginx-ingress ingress-nginx/ingress-nginx \
  --set controller.publishService.enabled=true \
  --set controller.service.externalIPs="{52.183.221.89}"

# ✅ VERIFICATION:
kubectl get pods -n default | grep nginx
# nginx-ingress-ingress-nginx-controller-958495fb5-zrdq7   1/1     Running

kubectl get svc -n default | grep nginx
# nginx-ingress-ingress-nginx-controller   LoadBalancer   10.43.235.205   52.183.221.89

curl http://52.183.221.89
# Returns nginx 404 (expected - routes not configured yet)
```

### 5. Verify Installation ✅ COMPLETED
```bash
# Check all components ✅
kubectl get nodes
kubectl get pods -n kube-system
kubectl get svc -n ingress-nginx

# Test ingress ✅
curl http://52.183.221.89
```

## Architecture

```
Internet → Nginx Ingress → Rocket.Chat Service → Rocket.Chat Pods (2 running)
                                       ↓
Internal MongoDB Service → MongoDB Pod (replica set enabled)
```

### Components ✅ DEPLOYED

- **Rocket.Chat Pods**: 2 running (anti-affinity removed for single-node testing) ✅
- **MongoDB Pod**: Single replica with replica set enabled ✅
- **MongoDB Init Job**: Completed successfully ✅
- **Nginx Ingress**: DaemonSet with hostNetwork on port 80 ✅
- **Traefik**: Disabled in k3s configuration ✅
- **ConfigMap**: Environment variables configured ✅
- **Service**: ClusterIP for internal load balancing ✅
- **Pod Disruption Budget**: Configured ✅

## Prerequisites ✅ ALL COMPLETED

### 1. Kubernetes Cluster ✅
- Running on Azure VM with public IP: `52.183.221.89`
- k3s installed and operational
- kubectl configured with fixed permissions

### 2. MongoDB ✅
- **Internal MongoDB**: Successfully deployed with replica set enabled
- **Replica Set**: Configured as `rs0` and operational
- **Authentication**: Username: `rocketchat`, Password: `rocketchat123`
- **Database**: `rocketchat` created and accessible

### 3. Nginx Ingress Controller ✅
- Installed via Helm
- Running and routing traffic
- Accessible at http://52.183.221.89

## Quick Deployment ✅ COMPLETED

### Option 1: Using the Deployment Script (Recommended) ✅ USED

```bash
cd k8s
chmod +x deploy.sh  # Fixed permission issue
./deploy.sh deploy  # Successfully deployed
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

### Verifying request distribution
During quick tests to the same path (for example `/api/info`), hash-by may send all requests to the same pod. Vary the path or query string to observe both pods serving traffic:
```bash
for i in {1..10}; do curl -s "http://52.183.221.89/api/info?x=$i" | jq -r '.instanceId? // .success'; done
```

To switch to round‑robin temporarily, remove the `upstream-hash-by` annotation in `k8s/nginx-ingress.yaml` and re-apply.

### External Load Balancing

For production-like setup with external nginx, use the configuration in `external-nginx-config` as a reference.

### Routing on k3s: Traefik vs Nginx ✅ RESOLVED
On k3s, Traefik runs by default and typically listens on host port 80. If Nginx Ingress is installed without host ports, browsers may still hit Traefik and see a 404 while cluster-side curls work.

**Resolution Applied:**
```bash
# Disabled Traefik and configured Nginx to own port 80
printf "disable:\n  - traefik\n" | sudo tee -a /etc/rancher/k3s/config.yaml
sudo systemctl restart k3s

helm upgrade nginx-ingress ingress-nginx/ingress-nginx \
  --reuse-values \
  --set controller.kind=DaemonSet \
  --set controller.hostNetwork=true \
  --set controller.daemonset.useHostPort=true
```

**Verification:**
```bash
# Check Nginx is on port 80
kubectl get pods -l app.kubernetes.io/name=ingress-nginx -o wide

# Verify Traefik is gone
kubectl get pods -n kube-system | grep traefik  # Should return nothing

# Test access
curl -sI http://52.183.221.89 | grep -E "^HTTP|X-Instance-ID"
```

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
