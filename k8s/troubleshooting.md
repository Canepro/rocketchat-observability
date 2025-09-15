# Rocket.Chat Kubernetes Troubleshooting Guide

## Overview

This guide helps troubleshoot common issues when deploying Rocket.Chat with 2 pods on your Azure VM Kubernetes cluster.

## Azure VM Setup Issues

### 1. Helm Installation Fails

**Symptoms:**
```bash
curl https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz -o helm.tar.gz
tar -zxvf helm.tar.gz
# Error: gzip: stdin: not in gzip format
# Error: tar: Child returned status 1
# Error: mv: cannot stat 'linux-amd64/helm': No such file or directory
```

**Root Cause:**
The Helm download failed or the file was corrupted, resulting in a small HTML file instead of the expected tar.gz archive.

**Solutions:**

#### Option 1: Retry Download with Better Error Handling
```bash
# Remove the corrupted file
rm -f helm.tar.gz

# Download with retry and verification
curl -L --retry 3 --retry-delay 5 https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz -o helm.tar.gz

# Verify file size (should be around 17MB)
ls -lh helm.tar.gz

# Extract and install
tar -zxvf helm.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
rm -rf linux-amd64 helm.tar.gz

# Verify installation
helm version
```

#### Option 2: Use Snap Package (Ubuntu/Debian)
```bash
# Install Helm via snap
sudo snap install helm --classic

# Verify installation
helm version
```

#### Option 3: Use Apt Package Manager
```bash
# Add Helm repository
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

# Update and install
sudo apt update
sudo apt install helm

# Verify installation
helm version
```

#### Option 4: Manual Binary Download
```bash
# Download latest version directly
wget https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz

# Or use a different mirror
curl -O https://mirrors.huaweicloud.com/helm/v3.13.0/helm-v3.13.0-linux-amd64.tar.gz

# Extract and install
tar -zxvf helm-v3.13.0-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
sudo chmod +x /usr/local/bin/helm

# Verify installation
helm version
```

#### Option 5: Use Snap (Most Reliable for Ubuntu)
```bash
# This is often the most reliable method on Ubuntu
sudo snap install helm --classic

# If snap fails, try updating snapd first
sudo apt update && sudo apt install snapd
sudo snap install helm --classic

# Verify installation
helm version
```

#### Option 6: Direct Binary Download with Verification
```bash
# Download Helm binary directly (most reliable)
cd /tmp
wget https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz

# If wget fails, try with curl and no progress bar
curl -s https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz -o helm-v3.13.0-linux-amd64.tar.gz

# Verify the download
ls -lh helm-v3.13.0-linux-amd64.tar.gz

# Extract
tar -xzf helm-v3.13.0-linux-amd64.tar.gz

# Move to PATH
sudo mv linux-amd64/helm /usr/local/bin/helm
sudo chmod +x /usr/local/bin/helm

# Clean up
rm -rf linux-amd64* helm-*

# Verify
helm version
```

### 5. Network/Download Issues

**Symptoms:**
```bash
curl -L --retry 3 --retry-delay 5 https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz -o helm.tar.gz
# Shows: 100  2061  100  2061    0     0    249      0  0:00:08
# File size: 2.2M instead of expected 15.4M
# tar: Unexpected EOF in archive
```

**Root Cause:**
Network connectivity issues, firewall blocking, or download interruptions.

**Solutions:**

#### Use a Different Download Method
```bash
# Method 1: Use wget instead of curl
wget --tries=3 https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz

# Method 2: Use aria2 for better download reliability
sudo apt install aria2
aria2c -x 16 -s 16 https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz

# Method 3: Download from GitHub releases
wget https://github.com/helm/helm/releases/download/v3.13.0/helm-v3.13.0-linux-amd64.tar.gz
```

#### Use Alternative Mirrors
```bash
# Huawei Cloud mirror
wget https://mirrors.huaweicloud.com/helm/v3.13.0/helm-v3.13.0-linux-amd64.tar.gz

# Alibaba Cloud mirror
wget https://mirrors.aliyun.com/helm/v3.13.0/helm-v3.13.0-linux-amd64.tar.gz

# Tencent Cloud mirror
wget https://mirrors.tencent.com/helm/v3.13.0/helm-v3.13.0-linux-amd64.tar.gz
```

#### Disable SSL Verification (if firewall blocks HTTPS)
```bash
# Only use as last resort if SSL is blocked
curl -k -L https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz -o helm.tar.gz
```

#### Use Proxy if Available
```bash
# If you have a proxy configured
export http_proxy="http://your-proxy:port"
export https_proxy="http://your-proxy:port"
curl -L https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz -o helm.tar.gz
```

### 6. Installation Verification Issues

**Symptoms:**
```bash
helm version
# Error: bash: /usr/local/bin/helm: cannot execute binary file: Exec format error
```

**Root Cause:**
Wrong architecture binary downloaded (e.g., ARM64 instead of AMD64).

**Solution:**
```bash
# Check your system architecture
uname -m

# For AMD64/x86_64 systems:
wget https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz

# For ARM64 systems:
wget https://get.helm.sh/helm-v3.13.0-linux-arm64.tar.gz

# Extract and install
tar -zxvf helm-v3.13.0-linux-*.tar.gz
sudo mv linux-*/helm /usr/local/bin/helm
```

### 7. Docker Group Membership Not Applied

**Symptoms:**
```bash
docker version
# Error: Got permission denied while trying to connect to the Docker daemon socket
```

**Root Cause:**
After adding user to docker group, you need to log out and log back in, or start a new shell session.

**Solution:**
```bash
# Option 1: Start new shell session
newgrp docker

# Option 2: Log out and log back in
# Close terminal and open new one

# Option 3: Restart your SSH session
exit
# Then reconnect via SSH

# Verify Docker access
docker version
docker run hello-world
```

### 8. k3s Not Starting Properly

**Symptoms:**
```bash
sudo systemctl status k3s
# Shows failed or inactive status
```

**Solutions:**
```bash
# Check k3s logs
sudo journalctl -u k3s -f

# Restart k3s service
sudo systemctl restart k3s

# Check if k3s is running
sudo systemctl status k3s

# Verify kubectl access
kubectl cluster-info
kubectl get nodes
```

### 9. kubectl Configuration Issues

**Symptoms:**
```bash
kubectl cluster-info
# Error: The connection to the server localhost:8080 was refused
```

**Solution:**
```bash
# Check if k3s is running
sudo systemctl status k3s

# Verify kubeconfig file
ls -la ~/.kube/config

# Check file permissions
ls -la /etc/rancher/k3s/k3s.yaml

# Re-copy kubeconfig if needed
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Test connection
kubectl cluster-info
```

## Quick Status Check

Use the deployment script for quick diagnostics:

```bash
cd k8s
./deploy.sh status
```

## Common Issues and Solutions

### 1. Pods Not Starting

**Symptoms:**
```bash
kubectl get pods -l app=rocketchat
# Shows pods in Pending or CrashLoopBackOff status
```

**Possible Causes & Solutions:**

#### MongoDB Connection Issues
```bash
# Check MongoDB connectivity
kubectl logs -l app=rocketchat --tail=50

# Test MongoDB connection from a pod
kubectl exec -it $(kubectl get pods -l app=rocketchat -o jsonpath='{.items[0].metadata.name}') -- mongo --host host.docker.internal --port 27017

# Update ConfigMap if MongoDB is not on host.docker.internal
kubectl edit configmap rocketchat-config
```

#### Resource Constraints
```bash
# Check resource usage
kubectl describe nodes

# Check pod resource requests/limits
kubectl describe pod $(kubectl get pods -l app=rocketchat -o jsonpath='{.items[0].metadata.name}')

# Scale down resources if needed
kubectl edit deployment rocketchat
```

#### Image Pull Issues
```bash
# Check image pull status
kubectl describe pod $(kubectl get pods -l app=rocketchat -o jsonpath='{.items[0].metadata.name}')

# Manually pull the image
kubectl run test-pod --image=rocketchat/rocket.chat:7.9.3 --rm -it --restart=Never -- /bin/bash
```

### 2. Cannot Access Rocket.Chat

**Symptoms:**
- Browser shows connection refused or 404 error
- `curl http://52.183.221.89` fails

**Solutions:**

#### Check Ingress Status
```bash
# Verify ingress
kubectl get ingress rocketchat-ingress
kubectl describe ingress rocketchat-ingress

# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/nginx-ingress-controller
```

#### Check Service Status
```bash
# Verify service
kubectl get svc rocketchat-service
kubectl describe svc rocketchat-service

# Test service connectivity
kubectl run test-pod --image=busybox --rm -it --restart=Never -- wget -O- rocketchat-service:80
```

#### Check Pod Health
```bash
# Check pod readiness
kubectl get pods -l app=rocketchat

# Check health endpoints
kubectl exec $(kubectl get pods -l app=rocketchat -o jsonpath='{.items[0].metadata.name}') -- curl -f http://localhost:3000/health
```

### 3. Load Balancing Issues

**Symptoms:**
- Requests not distributed between pods
- Sessions not sticky

**Solutions:**

#### Verify Pod Distribution
```bash
# Check pod IPs
kubectl get pods -l app=rocketchat -o wide

# Check service endpoints
kubectl get endpoints rocketchat-service
```

#### Test Load Balancing
```bash
# Monitor pod logs while making requests
kubectl logs -l app=rocketchat -f

# Make multiple requests and check which pod handles them
for i in {1..10}; do
  curl -s http://52.183.221.89/api/info | grep -o '"version":"[^"]*"' &
done
```

#### Check Nginx Configuration
```bash
# Check ingress-nginx logs
kubectl logs -n ingress-nginx deployment/nginx-ingress-controller

# Verify nginx configuration
kubectl exec -n ingress-nginx deployment/nginx-ingress-controller -- cat /etc/nginx/nginx.conf | grep rocketchat
```

### 4. Database Connection Issues

**Symptoms:**
- Rocket.Chat shows database connection errors
- Pods restart frequently

**Solutions:**

#### Test MongoDB Connectivity
```bash
# From a Rocket.Chat pod
kubectl exec -it $(kubectl get pods -l app=rocketchat -o jsonpath='{.items[0].metadata.name}') -- mongo --host host.docker.internal --port 27017

# Test database operations
kubectl exec -it $(kubectl get pods -l app=rocketchat -o jsonpath='{.items[0].metadata.name}') -- mongo rocketchat --host host.docker.internal --port 27017 --eval "db.stats()"
```

#### Update Connection Strings
```bash
# Edit ConfigMap
kubectl edit configmap rocketchat-config

# Update these values:
MONGO_URL: "mongodb://your-actual-mongodb-host:27017/rocketchat"
MONGO_OPLOG_URL: "mongodb://your-actual-mongodb-host:27017/local"

# Restart deployment
kubectl rollout restart deployment rocketchat
```

#### Check MongoDB Replica Set
```bash
# Connect to MongoDB and check replica set status
mongo --host host.docker.internal --port 27017
rs.status()
```

### 5. Performance Issues

**Symptoms:**
- Slow response times
- High resource usage
- Pods getting OOM killed

**Solutions:**

#### Resource Tuning
```bash
# Check current resource usage
kubectl top pods -l app=rocketchat
kubectl top nodes

# Adjust resource limits
kubectl edit deployment rocketchat
```

#### Database Performance
```bash
# Check MongoDB performance
kubectl exec -it $(kubectl get pods -l app=rocketchat -o jsonpath='{.items[0].metadata.name}') -- mongo rocketchat --host host.docker.internal --port 27017 --eval "db.serverStatus().connections"
```

#### Load Balancer Optimization
```bash
# Check nginx worker processes
kubectl exec -n ingress-nginx deployment/nginx-ingress-controller -- ps aux | grep nginx

# Monitor nginx metrics
kubectl exec -n ingress-nginx deployment/nginx-ingress-controller -- curl -s http://localhost:10254/metrics | grep nginx
```

### 6. Networking Issues

**Symptoms:**
- Inter-pod communication fails
- External access doesn't work

**Solutions:**

#### Network Policies
```bash
# Check network policies
kubectl get networkpolicies

# Test pod-to-pod communication
kubectl exec -it $(kubectl get pods -l app=rocketchat -o jsonpath='{.items[0].metadata.name}') -- ping $(kubectl get pods -l app=rocketchat -o jsonpath='{.items[1].metadata.name}' -o jsonpath='{.status.podIP}')
```

#### DNS Resolution
```bash
# Test DNS resolution
kubectl exec -it $(kubectl get pods -l app=rocketchat -o jsonpath='{.items[0].metadata.name}') -- nslookup rocketchat-service

# Check DNS configuration
kubectl exec -it $(kubectl get pods -l app=rocketchat -o jsonpath='{.items[0].metadata.name}') -- cat /etc/resolv.conf
```

### 7. SSL/TLS Issues

**Symptoms:**
- HTTPS doesn't work
- Certificate errors

**Solutions:**

#### Add TLS to Ingress
```yaml
# Edit ingress
kubectl edit ingress rocketchat-ingress

# Add TLS section:
spec:
  tls:
  - hosts:
    - 52.183.221.89
    secretName: rocketchat-tls
```

#### Certificate Management
```bash
# Check certificate status
kubectl get secrets rocketchat-tls

# Use cert-manager for automatic certificates
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

## Diagnostic Commands

### Health Checks
```bash
# Check all components
kubectl get all -l app=rocketchat

# Check pod health
kubectl describe pods -l app=rocketchat

# Check events
kubectl get events --sort-by='.lastTimestamp' | grep rocketchat
```

### Log Analysis
```bash
# Rocket.Chat logs
kubectl logs -l app=rocketchat --tail=100

# Specific pod logs
kubectl logs $(kubectl get pods -l app=rocketchat -o jsonpath='{.items[0].metadata.name}') --tail=100

# Previous container logs
kubectl logs $(kubectl get pods -l app=rocketchat -o jsonpath='{.items[0].metadata.name}') --previous --tail=100
```

### Network Debugging
```bash
# Port forwarding for debugging
kubectl port-forward svc/rocketchat-service 3000:80

# Test internal connectivity
kubectl run debug-pod --image=busybox --rm -it --restart=Never -- wget -O- rocketchat-service:80
```

## Emergency Recovery

### Restart Deployment
```bash
# Restart all pods
kubectl rollout restart deployment rocketchat

# Force recreate pods
kubectl delete pods -l app=rocketchat
```

### Full Redeployment
```bash
# Clean redeploy
cd k8s
./deploy.sh cleanup
./deploy.sh deploy
```

### Database Recovery
```bash
# If MongoDB data is corrupted, you may need to:
# 1. Stop Rocket.Chat
kubectl scale deployment rocketchat --replicas=0

# 2. Repair MongoDB (external process)
# 3. Restart Rocket.Chat
kubectl scale deployment rocketchat --replicas=2
```

## Monitoring and Alerting

### Enable Basic Monitoring
```bash
# Check pod metrics
kubectl top pods -l app=rocketchat

# Monitor resource usage over time
kubectl logs -l app=rocketchat -f | grep -E "(error|Error|ERROR)"
```

### Log Aggregation
```bash
# Collect logs for analysis
kubectl logs -l app=rocketchat --since=1h > rocketchat-logs.txt

# Search for specific errors
grep -i error rocketchat-logs.txt
```

## Getting Help

### Quick Diagnostic Script
```bash
#!/bin/bash
echo "=== Rocket.Chat Kubernetes Diagnostics ==="
echo "Pods:"
kubectl get pods -l app=rocketchat
echo ""
echo "Services:"
kubectl get svc -l app=rocketchat
echo ""
echo "Ingress:"
kubectl get ingress rocketchat-ingress
echo ""
echo "Events:"
kubectl get events --sort-by='.lastTimestamp' | tail -10
echo ""
echo "Pod Logs (last 10 lines):"
kubectl logs -l app=rocketchat --tail=10
```

### Support Information
When asking for help, provide:
1. Output of diagnostic commands above
2. Your Kubernetes version: `kubectl version`
3. Cluster information: `kubectl cluster-info`
4. MongoDB version and connection details
5. Steps to reproduce the issue

## Prevention

### Best Practices
1. **Monitor regularly**: Set up alerts for pod restarts and resource usage
2. **Backup database**: Regular MongoDB backups
3. **Update images**: Keep Rocket.Chat image updated
4. **Resource planning**: Monitor and adjust resource limits
5. **Network policies**: Implement proper network segmentation

### Proactive Monitoring
```bash
# Set up watch commands
watch -n 5 kubectl get pods -l app=rocketchat

# Monitor resource usage
kubectl top pods -l app=rocketchat --containers
```
