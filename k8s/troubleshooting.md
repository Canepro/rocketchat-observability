# Rocket.Chat Kubernetes Troubleshooting Guide

## Overview

This guide helps troubleshoot common issues when deploying Rocket.Chat with 2 pods on your Azure VM Kubernetes cluster.

## Azure VM Setup Issues

### ✅ RESOLVED: Multiple Azure VM Setup Issues

#### ✅ Helm Installation Issues
**Status:** Fixed with manual installation method
**Solution Used:** Remove snap and install manually from official source

#### ✅ kubectl Permission Issues
**Status:** Fixed with source kubeconfig permissions
**Solution Used:** `sudo chmod 644 /etc/rancher/k3s/k3s.yaml`

#### ✅ Nginx Ingress Controller
**Status:** Successfully deployed and running
**Verification:**
```bash
kubectl get pods -n default | grep nginx
# nginx-ingress-ingress-nginx-controller-958495fb5-zrdq7   1/1     Running

kubectl get svc -n default | grep nginx
# nginx-ingress-ingress-nginx-controller   LoadBalancer   10.43.235.205   52.183.221.89

curl http://52.183.221.89
# Returns nginx 404 (expected - no routes configured yet)
```

#### ✅ Repository Cloning Issues
**Status:** Successfully resolved
**Symptoms:**
```bash
git clone https://github.com/Canepro/rocketchat-observability.git
# fatal: could not create work tree dir 'rocketchat-observability': Permission denied
```

**Root Cause:**
Trying to clone into a directory without write permissions (like `/` for normal users).

**Solution Used:**
```bash
# Clone into home directory (recommended)
cd ~
git clone https://github.com/Canepro/rocketchat-observability.git
cd rocketchat-observability
git pull origin true-one-click

# Result: ✅ Successfully cloned 28 files
```

#### ✅ Script Execute Permission Issues
**Status:** Common issue after cloning
**Symptoms:**
```bash
./deploy.sh deploy
# -bash: ./deploy.sh: Permission denied
```

**Root Cause:**
Script file doesn't have execute permissions after cloning from Git.

**Solution:**
```bash
# If you're in the k8s directory already
chmod +x deploy.sh

# If you're in the project root directory
chmod +x k8s/deploy.sh

# Make all scripts executable at once (from project root)
chmod +x k8s/*.sh
chmod +x scripts/*.sh

# Then run deployment
cd k8s  # if not already there
./deploy.sh deploy
```

**Common Mistakes:**
```bash
# ❌ Wrong - you're already in k8s directory
chmod +x k8s/deploy.sh

# ✅ Correct - from k8s directory
chmod +x deploy.sh

# ✅ Correct - from project root
chmod +x k8s/deploy.sh
```

**Prevention:**
```bash
# After cloning, make scripts executable
cd rocketchat-observability
chmod +x k8s/deploy.sh
chmod +x scripts/*.sh
```

### 🚨 MongoDB Deployment Timeout Issues
**Symptoms:**
```bash
[INFO] Waiting for MongoDB to be ready...
error: timed out waiting for the condition on deployments/rocketchat-mongodb
```

**Root Cause:**
MongoDB pod is taking too long to become ready, or failing to start properly.

**Immediate Diagnosis:**
```bash
# Check MongoDB pod status
kubectl get pods -l app=mongodb

# Check pod details and events
kubectl describe pod $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}')

# Check MongoDB logs
kubectl logs -l app=mongodb --tail=50

# Check if MongoDB is actually running
kubectl exec $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}') -- mongo --eval "db.stats()"
```

**Common Solutions:**

#### 1. Resource Constraints
```bash
# Check node resources
kubectl describe nodes

# Check if MongoDB pod has resource issues
kubectl describe pod $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}')

# Scale down MongoDB resources if needed
kubectl edit deployment rocketchat-mongodb
# Change resources.requests and resources.limits
```

#### 2. MongoDB Startup Issues
```bash
# Check MongoDB logs for errors
kubectl logs -l app=mongodb -f

# Common issues:
# - Insufficient memory
# - Storage issues
# - Authentication problems
```

#### 3. Extend Timeout and Retry
```bash
# The deployment script has a 5-minute timeout
# You can wait longer manually:
kubectl wait --for=condition=available --timeout=600s deployment/rocketchat-mongodb

# Or check if it's actually ready
kubectl get pods -l app=mongodb
```

#### 4. Clean Restart
```bash
# Delete and redeploy MongoDB
kubectl delete deployment rocketchat-mongodb
kubectl delete service rocketchat-mongodb

# Wait a moment
sleep 10

# Redeploy
kubectl apply -f mongodb-deployment.yaml
kubectl apply -f mongodb-init-job.yaml

# Wait for readiness
kubectl wait --for=condition=available --timeout=300s deployment/rocketchat-mongodb
```

#### 5. Check MongoDB Configuration
```bash
# Verify MongoDB environment variables
kubectl exec $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}') -- env | grep MONGO

# Check if MongoDB is listening on correct port
kubectl exec $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}') -- netstat -tlnp | grep 27017
```

#### 10. MongoDB Init Job Timeout Issues
**Symptoms:**
```bash
[INFO] Initializing MongoDB replica set...
job.batch/rocketchat-mongodb-init unchanged
error: timed out waiting for the condition on jobs/rocketchat-mongodb-init
```

**Root Cause:**
MongoDB init job exists from previous deployment and hasn't completed successfully due to using wrong MongoDB client (`mongo` instead of `mongosh`).

**Immediate Diagnosis:**
```bash
# Check job status
kubectl get jobs
kubectl describe job rocketchat-mongodb-init

# Check job logs (shows infinite "Waiting for MongoDB..." loop)
kubectl logs $(kubectl get pods -l job-name=rocketchat-mongodb-init -o jsonpath='{.items[0].metadata.name}')

# Check if replica set is already initialized
kubectl exec $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}') -- /opt/bitnami/mongodb/bin/mongosh --eval "rs.status()"
```

**Solutions:**

#### Option 1: Clean Restart Init Job (RECOMMENDED)
```bash
# Delete the existing broken job
kubectl delete job rocketchat-mongodb-init

# Wait a moment
sleep 5

# Pull latest fixes (includes corrected MongoDB client paths)
cd ~/rocketchat-observability
git pull origin true-one-click

# Redeploy the fixed init job (use correct path based on your location)
# If you're in ~/rocketchat-observability/k8s:
kubectl apply -f mongodb-init-job.yaml

# If you're in ~/rocketchat-observability:
kubectl apply -f k8s/mongodb-init-job.yaml

# Wait for completion (should be quick now)
kubectl wait --for=condition=complete --timeout=60s job/rocketchat-mongodb-init
```

#### Option 2: Check if Replica Set Already Exists
```bash
# Connect to MongoDB and check status
kubectl exec $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}') -- /opt/bitnami/mongodb/bin/mongosh --eval "rs.status()"

# If replica set exists, you can skip the init job
# The deployment should continue without the init job
```

#### Option 3: Manual Replica Set Initialization
```bash
# Connect to MongoDB manually
kubectl exec -it $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}') -- /opt/bitnami/mongodb/bin/mongosh

# Run replica set initialization
rs.initiate({
  _id: 'rs0',
  members: [
    {
      _id: 0,
      host: 'rocketchat-mongodb:27017'
    }
  ]
});

# Exit and check status
rs.status()
```

#### Option 4: Force Continue Deployment
```bash
# If replica set is already initialized, continue manually
kubectl apply -f configmap.yaml
kubectl apply -f rocketchat-deployment.yaml
kubectl apply -f rocketchat-service.yaml
kubectl apply -f nginx-ingress.yaml
kubectl apply -f poddisruptionbudget.yaml
```

#### 11. Fix MongoDB Health Probe Issues (Bitnami Image)
```bash
# The issue: Bitnami MongoDB image doesn't have 'mongo' client in PATH
# Solution: Update the deployment with correct MongoDB client path

# Edit the MongoDB deployment
kubectl edit deployment rocketchat-mongodb

# Change the livenessProbe and readinessProbe from:
# exec:
#   command:
#   - mongo
#   - --eval
#   - db.adminCommand('ping')

# To:
# exec:
#   command:
#   - /opt/bitnami/mongodb/bin/mongo
#   - --eval
#   - db.adminCommand('ping')

# Or use mongosh (MongoDB 5.0+ shell)
# exec:
#   command:
#   - /opt/bitnami/mongodb/bin/mongosh
#   - --eval
#   - db.adminCommand('ping')
```

#### 7. Alternative: Use TCP Socket Probe
```bash
# Edit deployment and replace exec probes with tcpSocket
kubectl edit deployment rocketchat-mongodb

# Replace livenessProbe and readinessProbe with:
# tcpSocket:
#   port: 27017
# timeoutSeconds: 5
```

#### 8. Quick Fix: Disable Probes Temporarily
```bash
# Edit deployment to comment out probes temporarily
kubectl edit deployment rocketchat-mongodb

# Comment out livenessProbe and readinessProbe sections
# Then MongoDB should become ready immediately
```

#### 9. Directory Navigation Issues
```bash
# Common mistake: wrong directory name
cd ~/rocketchat-observability  # ✅ Correct
# Not: cd ~/rocketch            # ❌ Wrong

# Check current directory
pwd

# List directories in home
ls -la ~

# Navigate correctly
cd ~/rocketchat-observability/k8s
```

### 10. Nginx Ingress Annotation Issues
**Symptoms:**
```bash
kubectl apply -f nginx-ingress.yaml
# Error from server (BadRequest): admission webhook "validate.nginx.ingress.kubernetes.io" denied the request: nginx.ingress.kubernetes.io/configuration-snippet annotation cannot be used. Snippet directives are disabled by the Ingress administrator
```

**Root Cause:**
The nginx ingress controller has security restrictions that disable certain annotations like `configuration-snippet`.

**Solutions:**

#### Fix the Ingress Configuration
```bash
# Remove the problematic configuration-snippet annotation
# Move WebSocket directives to individual annotations

# In nginx-ingress.yaml, replace:
# nginx.ingress.kubernetes.io/configuration-snippet: |
#   proxy_set_header Upgrade $http_upgrade;
#   proxy_set_header Connection "upgrade";
#   proxy_buffering off;

# With:
nginx.ingress.kubernetes.io/proxy-set-headers: |
  X-Forwarded-Host $host
  X-Forwarded-Port $server_port
  X-Forwarded-Proto $scheme
  X-Real-IP $remote_addr
  X-Forwarded-For $proxy_add_x_forwarded_for
  X-Nginx-Proxy true
  Upgrade $http_upgrade
  Connection upgrade
nginx.ingress.kubernetes.io/proxy-buffering: "off"
nginx.ingress.kubernetes.io/proxy-request-buffering: "off"
```

#### Alternative: Minimal Ingress Configuration
```bash
# If you still get annotation errors, use a minimal configuration:
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rocketchat-ingress
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: rocketchat-service
            port:
              number: 80
```

### 12. Ingress Host Validation Issues
**Symptoms:**
```bash
kubectl apply -f nginx-ingress.yaml
# The Ingress "rocketchat-ingress" is invalid: spec.rules[0].host: Invalid value: "52.183.221.89": must be a DNS name, not an IP address
```

**Root Cause:**
Kubernetes ingress requires DNS names, not IP addresses in the host field.

**Solutions:**

#### Option 1: Remove Host Specification (Use Default Routing)
```bash
# Edit the ingress to remove the host field
kubectl edit ingress rocketchat-ingress

# Remove the host line:
# spec:
#   rules:
#   - host: "52.183.221.89"  # Remove this line
#     http:

# Or use this YAML:
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rocketchat-ingress
  annotations:
    nginx.ingress.kubernetes.io/upstream-hash-by: "$$request_uri$$host"
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
spec:
  ingressClassName: nginx
  rules:
  - http:  # No host specified - uses default routing
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: rocketchat-service
            port:
              number: 80
```

#### Option 2: Use a DNS Name
```bash
# Use a proper DNS name instead of IP
# Edit nginx-ingress.yaml and change:
# - host: "52.183.221.89"
# To:
# - host: "rocketchat.local"  # or your actual domain

# Then update your /etc/hosts or DNS
echo "52.183.221.89 rocketchat.local" >> /etc/hosts
```

#### Option 3: Use IP-Based Routing (Advanced)
```bash
# For IP-based access, you can use this annotation
kubectl edit ingress rocketchat-ingress

# Add annotation:
# nginx.ingress.kubernetes.io/use-regex: "true"
# nginx.ingress.kubernetes.io/rewrite-target: /
```

### 13. Rocket.Chat Pod Startup Issues
**Symptoms:**
```bash
kubectl get pods -l app=rocketchat
# NAME                     READY   STATUS              RESTARTS   AGE
# rocketchat-xxx-yyy       0/1     Pending             0          2m
# rocketchat-xxx-zzz       0/1     Error               1          2m
```

**Root Cause:**
Resource constraints, MongoDB connectivity issues, or pod scheduling problems.

**Immediate Diagnosis:**
```bash
# Check pod details
kubectl describe pod $(kubectl get pods -l app=rocketchat -o jsonpath='{.items[0].metadata.name}')

# Check pod logs (even if in error state)
kubectl logs $(kubectl get pods -l app=rocketchat -o jsonpath='{.items[0].metadata.name}') --previous

# Check events
kubectl get events --sort-by='.lastTimestamp' | grep rocketchat

# Check node resources
kubectl describe nodes
```

**Common Solutions:**

#### Resource Constraints
```bash
# Check if pods can't be scheduled due to resource limits
kubectl describe node myvm

# Reduce resource requests if needed
kubectl edit deployment rocketchat
# Lower the requests.memory and requests.cpu values
```

#### MongoDB Connectivity
```bash
# Verify MongoDB is accessible
kubectl exec $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}') -- /opt/bitnami/mongodb/bin/mongosh --eval "db.stats()"

# Test service connectivity
kubectl run test-pod --image=busybox --rm -it --restart=Never -- wget -O- rocketchat-mongodb:27017
```

#### Image Pull Issues
```bash
# Check if Rocket.Chat image is pulling correctly
kubectl describe pod $(kubectl get pods -l app=rocketchat -o jsonpath='{.items[0].metadata.name}')

# Look for ImagePullBackOff errors
```

#### Clean Restart
```bash
# Delete problematic pods
kubectl delete pods -l app=rocketchat

# Or restart the entire deployment
kubectl rollout restart deployment rocketchat

# Check status
kubectl get pods -l app=rocketchat -w
```

### 14. Pod Anti-Affinity Scheduling Issues ⚠️ BLOCKS 2 PODS ON SINGLE NODE
**Symptoms:**
```bash
kubectl get pods -l app=rocketchat
# NAME                     READY   STATUS    RESTARTS   AGE
# rocketchat-xxx-yyy       0/1     Pending   0          5m
# rocketchat-xxx-zzz       0/1     Running  0          5m

# Events show:
# Warning  FailedScheduling  0/1 nodes are available: 1 node(s) didn't match pod anti-affinity rules.
```

**Root Cause:**
Pod anti-affinity rules prevent multiple pods from running on the same node:
- `requiredDuringSchedulingIgnoredDuringExecution`: Hard requirement - blocks 2nd pod
- `preferredDuringSchedulingIgnoredDuringExecution`: Soft preference - still prevents 2nd pod on single node

**IMPORTANT FOR 2 PODS:** Even with "preferred" anti-affinity, Kubernetes will NOT schedule a second pod on the same node if it can avoid it. For testing with 2 Rocket.Chat pods on a single-node cluster, you MUST remove anti-affinity entirely.

**Solutions:**

#### Solution 1: REMOVE Anti-Affinity Completely (REQUIRED for 2 pods)
```bash
# Edit deployment and DELETE the entire affinity section
kubectl edit deployment rocketchat

# Find and DELETE this entire block:
spec:
  template:
    spec:
      affinity:                    # ← DELETE FROM HERE
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - rocketchat
              topologyKey: kubernetes.io/hostname  # ← TO HERE
      # Keep everything else below
```

#### Solution 2: Update YAML File and Reapply
```yaml
# In rocketchat-deployment.yaml, comment out the affinity section:
spec:
  template:
    spec:
      # COMMENT OUT OR DELETE THIS ENTIRE BLOCK FOR 2 PODS:
      # affinity:
      #   podAntiAffinity:
      #     preferredDuringSchedulingIgnoredDuringExecution:
      #     - weight: 100
      #       podAffinityTerm:
      #         labelSelector:
      #           matchExpressions:
      #           - key: app
      #             operator: In
      #             values:
      #           - rocketchat
      #         topologyKey: kubernetes.io/hostname
```

Then apply and scale:
```bash
kubectl apply -f rocketchat-deployment.yaml
kubectl scale deployment rocketchat --replicas=2
kubectl get pods -l app=rocketchat -w
```

#### Alternative: Keep 1 Pod (Current State)
```bash
# For testing on single node, use only 1 replica
kubectl scale deployment rocketchat --replicas=1

# Then scale back up when you have more nodes
kubectl scale deployment rocketchat --replicas=2
```

#### Verify After Removing Anti-Affinity
```bash
# After removing anti-affinity, scale to 2 replicas
kubectl scale deployment rocketchat --replicas=2

# Both pods should now run on the same node
kubectl get pods -l app=rocketchat -o wide
# NAME                     READY   STATUS    NODE
# rocketchat-xxx-yyy       1/1     Running   myvm
# rocketchat-xxx-zzz       1/1     Running   myvm  # Same node!

# Check events
kubectl get events --sort-by='.lastTimestamp' | grep rocketchat
```

**Expected Result for 2 Pods Testing:**
- ✅ With anti-affinity removed: 2 pods running on same node
- ❌ With anti-affinity (any type): Only 1 pod runs, 2nd stays Pending

### 14.1 Are two Rocket.Chat pods expected to work?
**Yes.** In monolithic mode, multiple Rocket.Chat pods behind a single Service and Ingress are fully supported. For single-node testing, remove pod anti-affinity so both pods can schedule on the same node. Ensure MongoDB replica set is enabled and healthy.

#### Quick validation
```bash
# Expect 2 Running pods
kubectl get pods -l app=rocketchat -o wide

# Hit API multiple times; responses should succeed (200) consistently
for i in {1..10}; do curl -s http://52.183.221.89/api/info | jq -r '.success'; done

# Optional: watch logs from both pods while generating traffic
kubectl logs -l app=rocketchat -f | sed -n 's/.*hostname\":\"\([^"]\+\).*/pod: \1/p'
```

### 14.2 Hash-based load balancing nuances (nginx)
This ingress uses hash-based upstream selection:
- **Annotation:** `nginx.ingress.kubernetes.io/upstream-hash-by: "$$request_uri$$host"`
- **Effect:** Requests with the same URI+Host tend to hit the same pod (sticky by path), so quick tests to `/api/info` may appear to prefer one pod.
- **WebSockets:** Upgrade headers are set; long-lived connections remain on the selected pod until reconnect.

#### How to verify distribution
```bash
# Vary the path to influence hash and observe both pods serve traffic
for p in {1..10}; do curl -s "http://52.183.221.89/api/info?x=$p" | jq -r '.instanceId? // .version' ; done

# Or fetch root repeatedly and check nginx access logs (controller)
kubectl logs -l app.kubernetes.io/name=ingress-nginx --tail=200 | grep -E "/api/info|GET / "
```

#### Switching to round-robin (optional)
Remove the `upstream-hash-by` annotation from `nginx-ingress.yaml` for classic round-robin during testing.

### 14.3 404 page not found via public IP
**Diagnosis outcome:** Kubernetes components were healthy and routing correctly; `/api/info` returned 200 via ingress. The 404 was external to the cluster (browser cache, intermediary proxy, or Azure NSG).

#### Things to check on Azure
- **NSG rules:** Ensure inbound TCP 80 from Internet to VM is allowed.
- **Linux firewall:** `sudo ufw status` → allow 80/tcp or disable for testing.
- **Public IP health:** `curl -I http://52.183.221.89` from an external network.
- **Browser cache:** Hard refresh or test in an incognito window.

#### In-cluster verification (already confirmed)
```bash
kubectl get ingress rocketchat-ingress
curl -s http://52.183.221.89/api/info | jq
kubectl logs -l app.kubernetes.io/name=ingress-nginx --tail=200 | grep /api/info
```

### 15. MongoDB Connection Issues ✅ RESOLVED
**Symptoms:**
```bash
kubectl logs $(kubectl get pods -l app=rocketchat --field-selector=status.phase!=Pending -o jsonpath='{.items[0].metadata.name}') --previous
# MongoTopologyClosedError: Topology is closed
# MongoServerSelectionError: Server selection timed out after 30000 ms
# ReplicaSetNoPrimary
```

**Root Cause:**
MongoDB replica set not properly initialized or authentication issues preventing Rocket.Chat from connecting.

**Immediate Diagnosis:**
```bash
# Check MongoDB pod status
kubectl get pods -l app=mongodb

# Check MongoDB logs
kubectl logs $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}')

# Check init job status
kubectl get jobs
kubectl logs $(kubectl get pods -l job-name=rocketchat-mongodb-init -o jsonpath='{.items[0].metadata.name}')

# Test MongoDB connectivity
kubectl exec $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}') -- /opt/bitnami/mongodb/bin/mongosh --eval "db.adminCommand('ping')"
```

**Quick Fixes:**

#### Fix 1: Reinitialize Replica Set
```bash
# Delete the old init job
kubectl delete job rocketchat-mongodb-init

# Connect to MongoDB directly
kubectl exec -it $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}') -- /opt/bitnami/mongodb/bin/mongosh

# In MongoDB shell:
rs.initiate({
  _id: 'rs0',
  members: [
    {
      _id: 0,
      host: 'rocketchat-mongodb:27017'
    }
  ]
});

# Exit MongoDB shell and check status
rs.status();
```

#### Fix 2: Test Authentication
```bash
# Test root authentication
kubectl exec $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}') -- /opt/bitnami/mongodb/bin/mongosh --username root --password rocketchat123 --authenticationDatabase admin --eval "db.adminCommand('ping')"

# Test rocketchat user authentication
kubectl exec $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}') -- /opt/bitnami/mongodb/bin/mongosh --username rocketchat --password rocketchat123 --authenticationDatabase rocketchat --eval "db.stats()"
```

#### Fix 3: Remove Authentication Temporarily (For Testing)
```bash
# Edit ConfigMap to remove authentication (temporary)
kubectl edit configmap rocketchat-config

# Change:
MONGO_URL: "mongodb://rocketchat-mongodb:27017/rocketchat?replicaSet=rs0"
MONGO_OPLOG_URL: "mongodb://rocketchat-mongodb:27017/local?replicaSet=rs0"

# To:
MONGO_URL: "mongodb://rocketchat-mongodb:27017/rocketchat"
MONGO_OPLOG_URL: "mongodb://rocketchat-mongodb:27017/local"
```

#### Fix 4: Restart Everything
```bash
# Restart MongoDB
kubectl delete pod $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}')

# Wait for MongoDB to restart
kubectl wait --for=condition=ready pod -l app=mongodb --timeout=300s

# Restart Rocket.Chat pods
kubectl delete pods -l app=rocketchat

# Check status
kubectl get pods -l app=rocketchat -w
```

#### Verify MongoDB Replica Set Status
```bash
# Connect to MongoDB and check replica set
kubectl exec -it $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}') -- /opt/bitnami/mongodb/bin/mongosh

# Check replica set status
rs.status();

# Check if rocketchat database exists
show dbs;

# Exit
exit;
```

**Priority Order:**
1. **Reinitialize Replica Set** (Most likely fix)
2. **Test Authentication** (Verify credentials)
3. **Remove Authentication** (Temporary workaround)
4. **Restart Everything** (Last resort)

### 16. MongoDB NoReplicationEnabled Error ✅ RESOLVED
**Symptoms:**
```bash
kubectl exec -it $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}') -- /opt/bitnami/mongodb/bin/mongosh
# MongoServerError[NoReplicationEnabled]: This node was not started with replication enabled
# MongoServerError[NoReplicationEnabled]: not running with --replSet
```

**Root Cause:**
MongoDB deployment was missing replica set configuration environment variables.

**Solution Applied:**
```yaml
# In mongodb-deployment.yaml, added:
- name: MONGODB_REPLICA_SET_MODE
  value: "primary"
- name: MONGODB_REPLICA_SET_KEY
  value: "replicasetkey123"
- name: MONGODB_ADVERTISED_HOSTNAME
  value: "rocketchat-mongodb"
```

**Fix Steps:**
```bash
# Delete old MongoDB deployment
kubectl delete deployment rocketchat-mongodb

# Apply updated configuration
kubectl apply -f mongodb-deployment.yaml

# Wait for MongoDB to be ready
kubectl wait --for=condition=available --timeout=300s deployment/rocketchat-mongodb

# Restart Rocket.Chat pods
kubectl delete pods -l app=rocketchat

# Verify pods are running
kubectl get pods -l app=rocketchat
```

**Verification:**
```bash
# Check replica set status
kubectl exec $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}') -- /opt/bitnami/mongodb/bin/mongosh --username root --password rocketchat123 --authenticationDatabase admin --eval "rs.status()"
# Should show: "ok": 1 with member state as PRIMARY
```

## ✅ DEPLOYMENT SUCCESS SUMMARY

### Successfully Resolved Issues:
1. ✅ **Helm Installation** - Removed snap version, installed manually
2. ✅ **kubectl Permissions** - Fixed kubeconfig file permissions
3. ✅ **Nginx Ingress** - Removed configuration-snippet, fixed host validation
4. ✅ **MongoDB Health Probes** - Fixed client path (`mongo` → `/opt/bitnami/mongodb/bin/mongosh`)
5. ✅ **MongoDB Init Job** - Fixed client path for replica set initialization
6. ✅ **Pod Anti-Affinity** - REMOVED entirely for 2-pod testing on single node
7. ✅ **MongoDB Replication** - Added replica set configuration environment variables
8. ✅ **ReplicaSet Cleanup** - Removed old ReplicaSets causing persistent pending pods
9. ✅ **2-Pod Deployment** - Successfully running 2 Rocket.Chat instances
10. ✅ **Load Balancing** - Hash-based routing configured via Nginx Ingress

### Final Deployment Status:
```bash
# MongoDB: Running with replica set enabled
kubectl get pods -l app=mongodb
# rocketchat-mongodb-xxx   1/1     Running   0          50m

# Rocket.Chat: 2 pods running (anti-affinity removed for single-node)
kubectl get pods -l app=rocketchat -o wide
# NAME                          READY   STATUS    RESTARTS   AGE     IP           NODE
# rocketchat-7bc55f5795-66dbt   1/1     Running   0          15m     10.42.0.20   myvm
# rocketchat-7bc55f5795-n645p   1/1     Running   0          4m      10.42.0.21   myvm

# Ingress: Configured with hash-based load balancing
kubectl get ingress
# rocketchat-ingress   nginx   *   52.183.221.89   80   65m

# API Health Check - Both pods operational
curl -s http://52.183.221.89/api/info | jq -r '.success'
# Returns: true

# Instance IDs (different for each pod)
# Pod 1: 646c00b4-e775-485a-816c-72347b6e9a44
# Pod 2: 324957db-dce5-4644-a9aa-ec0a5db3dec7
```

### Access Information:
- **URL:** http://52.183.221.89
- **Pods:** 2 instances with load balancing
- **Admin:** Existing admin user (ADMIN_PASS ignored)
- **Status:** ✅ FULLY OPERATIONAL WITH 2 PODS

### 17. Persistent Pending Pods After Scaling
**Symptoms:**
```bash
kubectl scale deployment rocketchat --replicas=1
# Scaled successfully, but pending pods keep reappearing
kubectl get pods -l app=rocketchat
# rocketchat-xxx-yyy   1/1     Running   0          35m
# rocketchat-xxx-zzz   0/1     Pending   0          12s  # Keeps coming back
```

**Root Cause:**
Multiple ReplicaSets exist from previous deployment updates, and they maintain their desired replica count independently.

**Diagnosis:**
```bash
# Check all ReplicaSets
kubectl get rs -l app=rocketchat
# NAME                    DESIRED   CURRENT   READY   AGE
# rocketchat-796fd8f57    1         1         1       80m  # Current
# rocketchat-7bc55f5795   1         1         0       47m  # Old, still trying to create pods
```

**Solution:**

#### Option 1: Scale Old ReplicaSets to Zero
```bash
# List all ReplicaSets
kubectl get rs -l app=rocketchat

# Scale old ReplicaSets to 0
kubectl scale rs rocketchat-7bc55f5795 --replicas=0

# Delete any pending pods
kubectl delete pod rocketchat-7bc55f5795-xxxxx
```

#### Option 2: Delete Old ReplicaSets
```bash
# Delete old ReplicaSets entirely
kubectl delete rs rocketchat-7bc55f5795

# Note: This may recreate if the deployment still references it
```

#### Option 3: Clean Deployment Update (RECOMMENDED)
```bash
# Get current deployment revision
kubectl rollout history deployment rocketchat

# Delete all old ReplicaSets at once
kubectl delete rs $(kubectl get rs -l app=rocketchat -o jsonpath='{.items[?(@.spec.replicas==0)].metadata.name}')

# Or manually delete each old ReplicaSet
kubectl get rs -l app=rocketchat --no-headers | grep " 0 " | awk '{print $1}' | xargs kubectl delete rs
```

#### Option 4: Force Single ReplicaSet
```bash
# Edit deployment to ensure only 1 replica
kubectl edit deployment rocketchat
# Set: spec.replicas: 1

# Then clean up all ReplicaSets except the current one
kubectl get rs -l app=rocketchat -o json | jq -r '.items[] | select(.status.replicas==0) | .metadata.name' | xargs -I {} kubectl delete rs {}
```

**Prevention:**
```bash
# When updating deployments, use --record for history
kubectl apply -f rocketchat-deployment.yaml --record

# Clean up old ReplicaSets periodically
kubectl delete rs -l app=rocketchat --field-selector status.replicas=0
```

**Verification:**
```bash
# Should show only one ReplicaSet with DESIRED=2
kubectl get rs -l app=rocketchat
# NAME                    DESIRED   CURRENT   READY   AGE
# rocketchat-7bc55f5795   2         2         2       10m

# Should show 2 running pods
kubectl get pods -l app=rocketchat
# NAME                          READY   STATUS    RESTARTS   AGE
# rocketchat-7bc55f5795-66dbt   1/1     Running   0          15m
# rocketchat-7bc55f5795-n645p   1/1     Running   0          4m
```

### 18. Old ReplicaSet Creating Persistent Pending Pods ⚠️ ONGOING ISSUE
**Symptoms:**
```bash
kubectl get pods -l app=rocketchat
# NAME                          READY   STATUS    RESTARTS   AGE
# rocketchat-75b8d4f968-4kplt   0/1     Pending   0          2m    # ← Old ReplicaSet
# rocketchat-7bc55f5795-66dbt   1/1     Running   0          15m   # ← Current (working)
# rocketchat-7bc55f5795-n645p   1/1     Running   0          4m    # ← Current (working)

kubectl get rs -l app=rocketchat
# NAME                    DESIRED   CURRENT   READY   AGE
# rocketchat-75b8d4f968   1         1         0       10m   # ← Old ReplicaSet with anti-affinity
# rocketchat-7bc55f5795   2         2         2       5m    # ← Current ReplicaSet without anti-affinity
```

**Root Cause:**
Old ReplicaSet from when deployment had anti-affinity enabled still exists and tries to maintain its desired replica count.

**Solutions:**

#### Solution 1: Delete Old ReplicaSet (Quick Fix)
```bash
# Delete the old ReplicaSet
kubectl delete rs rocketchat-75b8d4f968

# Verify only current ReplicaSet remains
kubectl get rs -l app=rocketchat
```

#### Solution 2: Clean Deployment Recreation (Permanent Fix)
```bash
# Save current deployment
kubectl get deployment rocketchat -o yaml > rocketchat-backup.yaml

# Delete deployment completely
kubectl delete deployment rocketchat

# Delete ALL ReplicaSets
kubectl delete rs -l app=rocketchat --all

# Recreate from clean YAML
kubectl apply -f rocketchat-deployment.yaml

# Scale to 2 pods
kubectl scale deployment rocketchat --replicas=2

# Verify clean state
kubectl get rs -l app=rocketchat
kubectl get pods -l app=rocketchat
```

#### Solution 3: Force Rollout Restart
```bash
# Force deployment to create new ReplicaSet
kubectl rollout restart deployment rocketchat

# Delete old ReplicaSets after rollout
kubectl delete rs $(kubectl get rs -l app=rocketchat -o jsonpath='{.items[?(@.status.replicas==0)].metadata.name}')
```

**Expected Result After Fix:**
```bash
kubectl get rs -l app=rocketchat
# NAME                    DESIRED   CURRENT   READY   AGE
# rocketchat-7bc55f5795   2         2         2       2m    # Only one ReplicaSet

kubectl get pods -l app=rocketchat
# NAME                          READY   STATUS    RESTARTS   AGE
# rocketchat-7bc55f5795-66dbt   1/1     Running   0          2m
# rocketchat-7bc55f5795-n645p   1/1     Running   0          2m
# No pending pods from old ReplicaSet
```

**Verification:**
```bash
# MongoDB pod status
kubectl get pods -l app=mongodb
# rocketchat-mongodb-xxxxxxxxxx-xxxxx   1/1     Running   0          5m

# Init job completed successfully
kubectl get jobs
# rocketchat-mongodb-init   Complete   1/1           11s        2m

# Init job logs show success
kubectl logs $(kubectl get pods -l job-name=rocketchat-mongodb-init -o jsonpath='{.items[0].metadata.name}')
# MongoDB is ready. Initializing replica set...
# Replica set initialized successfully
```

```bash
# Both issues resolved:
# 1. Helm: Remove snap, manual install
sudo snap remove helm
wget https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz
tar -zxvf helm-v3.13.0-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm

# 2. kubectl: Fix source kubeconfig permissions
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
sudo chown root:root /etc/rancher/k3s/k3s.yaml
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Verification:
kubectl cluster-info  # ✅ Working
kubectl get nodes     # ✅ Shows k3s node ready
```

**Common Issues Resolved:**
- Network download failures → Use `wget` instead of `curl`
- Snap compatibility issues → Remove snap and install manually
- Architecture mismatches → Verify with `uname -m`
- Segmentation faults → Clean environment installation
- kubectl permission denied → Fix source kubeconfig permissions

---

### 1. Alternative Helm Installation Methods (Reference)

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

### 7. Helm Segmentation Fault

**Symptoms:**
```bash
helm version
# Segmentation fault
```

**Root Cause:**
Snap version compatibility issues, environment conflicts, or corrupted installation.

**Solutions:**

#### Option 1: Remove Snap and Install Manually
```bash
# Remove snap version
sudo snap remove helm

# Install manually from official source
wget https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz
tar -zxvf helm-v3.13.0-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
sudo chmod +x /usr/local/bin/helm

# Verify
helm version
```

#### Option 2: Fix Snap Environment Issues
```bash
# Check snap version and refresh
snap list | grep helm
sudo snap refresh helm

# If that fails, remove and reinstall
sudo snap remove helm
sudo snap install helm --classic

# Try with different shell
bash -c "helm version"
```

#### Option 3: Use Alternative Snap Channel
```bash
# Remove current snap
sudo snap remove helm

# Install from edge channel (may have fixes)
sudo snap install helm --edge

# Or try beta channel
sudo snap install helm --beta
```

#### Option 4: Check Environment Variables
```bash
# Check for conflicting environment variables
env | grep -i helm
env | grep -i kube

# Temporarily clear problematic variables
unset KUBECONFIG
unset HELM_CONFIG_HOME

# Try again
helm version
```

#### Option 5: Install via Apt Repository
```bash
# Remove snap first
sudo snap remove helm

# Add Helm apt repository
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

# Install
sudo apt update
sudo apt install helm

# Verify
helm version
```

#### Option 6: Manual Binary with Clean Environment
```bash
# Remove snap completely
sudo snap remove --purge helm

# Download and install in clean environment
cd /tmp
wget https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz
tar -xzf helm-v3.13.0-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin/helm-manual
sudo chmod +x /usr/local/bin/helm-manual

# Test with full path
/usr/local/bin/helm-manual version

# If works, replace the system helm
sudo mv /usr/local/bin/helm-manual /usr/local/bin/helm
```

### 8. Docker Group Membership Not Applied

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

### 9. k3s Not Starting Properly

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

### 10. kubectl Configuration Issues

**Symptoms:**
```bash
kubectl get pods
# WARN[0000] Unable to read /etc/rancher/k3s/k3s.yaml, please start server with --write-kubeconfig-mode or --write-kubeconfig-group to modify kube config permissions
# error: error loading config file "/etc/rancher/k3s/k3s.yaml": open /etc/rancher/k3s/k3s.yaml: permission denied
```

**Root Cause:**
k3s kubeconfig file has incorrect permissions for the regular user.

**Solutions:**

#### Option 1: Fix kubeconfig permissions (Recommended)
```bash
# Check current permissions
ls -la ~/.kube/config
ls -la /etc/rancher/k3s/k3s.yaml

# Fix the SOURCE kubeconfig file permissions
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
sudo chown root:root /etc/rancher/k3s/k3s.yaml

# Copy kubeconfig with correct permissions for user
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
sudo chmod 600 ~/.kube/config

# Alternative: Regenerate kubeconfig with proper permissions
sudo -i
k3s kubectl config view --raw > /etc/rancher/k3s/k3s.yaml
chmod 644 /etc/rancher/k3s/k3s.yaml
exit

# Copy to user home
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Test connection
kubectl cluster-info
kubectl get nodes
```

#### Option 2: Use sudo with kubectl
```bash
# Use sudo for kubectl commands
sudo kubectl get pods
sudo kubectl get svc

# Or create an alias
echo "alias k='sudo kubectl'" >> ~/.bashrc
source ~/.bashrc
k get pods
```

#### Option 3: Fix k3s service permissions
```bash
# Stop k3s service
sudo systemctl stop k3s

# Start k3s with proper kubeconfig permissions
sudo k3s server --write-kubeconfig-mode 644

# Or modify the service file
sudo systemctl edit k3s
# Add: [Service]
# Environment=K3S_KUBECONFIG_MODE=644

# Restart k3s
sudo systemctl daemon-reload
sudo systemctl restart k3s

# Wait for k3s to restart
sleep 10

# Re-copy kubeconfig
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

#### Option 4: Regenerate kubeconfig as k3s user
```bash
# Switch to root and regenerate
sudo -i
k3s kubectl config view --raw > /etc/rancher/k3s/k3s.yaml
chmod 644 /etc/rancher/k3s/k3s.yaml
exit

# Copy to user home
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Test
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
  curl -s http://52.183.221.89/api/info | jq -r '.success' &
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

### 14.4 Browser shows 404 but curl shows 200 (Traefik vs Nginx)
**Symptom:** Browser Network tab shows `GET /` → 404 Not Found. From the VM: `curl -I http://52.183.221.89` returns 200 with Rocket.Chat headers.

**Root cause:** In k3s, the built-in Traefik is exposed on host port 80 by default. If Nginx Ingress is installed without host ports, some clients may still hit Traefik and receive its 404, while server-side curls can reach the correct ingress path. Extensions (e.g., ones injecting `inject.js`) and HTTPS upgrades can also interfere.

**Quick fixes:**
```bash
# Option A (temporary): Route via Traefik too
kubectl apply -f k8s/traefik-ingress.yaml

# Option B (preferred): Disable Traefik and let Nginx own port 80
printf "disable:\n  - traefik\n" | sudo tee -a /etc/rancher/k3s/config.yaml
sudo systemctl restart k3s

# Then run Nginx as DaemonSet with hostNetwork/hostPort
helm upgrade nginx-ingress ingress-nginx/ingress-nginx \
  --reuse-values \
  --set controller.kind=DaemonSet \
  --set controller.hostNetwork=true \
  --set controller.daemonset.useHostPort=true \
  --set controller.service.type=ClusterIP \
  --set controller.publishService.enabled=false

# Verify
curl -I http://52.183.221.89
```

**Client-side checks:**
- Use incognito/private window and hard refresh (Ctrl+Shift+R)
- Disable extensions (look for `inject.js` in console)
- Ensure using http (not force-upgraded https)
