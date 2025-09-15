# Rocket.Chat Kubernetes Troubleshooting Guide

## Overview

This guide helps troubleshoot common issues when deploying Rocket.Chat with 2 pods on your Azure VM Kubernetes cluster.

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
