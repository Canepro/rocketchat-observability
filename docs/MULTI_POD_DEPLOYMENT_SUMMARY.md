# Rocket.Chat Multi-Pod Kubernetes Deployment Summary Report

## Executive Summary

This report documents the comprehensive findings, challenges, and lessons learned from deploying Rocket.Chat with 2+ pods on a single-node Kubernetes cluster (k3s on Azure VM) without microservices enabled. The deployment successfully achieved full operational status with hash-based load balancing, but encountered numerous technical challenges that required systematic resolution.

## 📊 Deployment Overview

### Final Architecture

- **Platform**: Single-node Kubernetes (k3s) on Azure VM
- **Pods**: 2 Rocket.Chat pods (monolithic mode, no microservices)
- **Database**: Internal MongoDB with replica set enabled
- **Ingress**: Nginx Ingress Controller with hash-based load balancing
- **Load Balancing**: Hash-based routing (`$$request_uri$$host`)
- **Access**: http://52.183.221.89 (NodePort: 30080, LoadBalancer: 31229)

### Success Metrics
- ✅ **2 pods running successfully** on single node (anti-affinity removed)
- ✅ **Hash-based load balancing** operational with pod distribution
- ✅ **MongoDB replica set** properly initialized and healthy
- ✅ **WebSocket support** enabled for real-time features
- ✅ **Full Rocket.Chat functionality** verified and operational

## 🔍 Key Findings

### 1. Pod Anti-Affinity Critical Blocker
**Finding**: Even "preferred" anti-affinity prevents 2nd pod scheduling on single-node clusters.

**Impact**: 🚨 **Blocker** - Only 1 pod could run despite having resources for 2.

**Resolution**: Complete removal of affinity rules required for single-node testing.

```yaml
# REMOVED - This blocks 2 pods on single node:
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution: [...]
```

### 2. MongoDB Replica Set Initialization Complexity
**Finding**: Replica set initialization requires correct MongoDB client path and timing.

**Challenges**:
- Wrong client path (`mongo` vs `/opt/bitnami/mongodb/bin/mongosh`)
- Bitnami image health probe path issues
- Init job timeout and loop issues

**Resolution**: Fixed client paths and added proper replica set configuration.

### 3. Nginx Ingress Controller Port Conflicts
**Finding**: k3s ServiceLB (svclb) automatically claims host ports, preventing DaemonSet scheduling.

**Resolution**: Switched to NodePort service type to avoid port conflicts.

### 4. Load Balancing Verification Challenges
**Finding**: Hash-based routing may appear to favor one pod during simple testing.

**Verification Method**: Use varied query parameters to force pod distribution:
```bash
for i in {1..10}; do
  curl -s "http://52.183.221.89/api/info?x=$i" | jq -r '.instanceId'
done
```

## 🚧 Major Challenges Encountered

### Critical Issues Resolved

| Issue | Severity | Root Cause | Resolution Status |
|-------|----------|------------|------------------|
| Pod Anti-Affinity Blocking | 🚨 Critical | Required affinity prevents 2 pods on single node | ✅ **RESOLVED** - Removed affinity |
| MongoDB Health Probes | 🚨 Critical | Wrong client path in Bitnami image | ✅ **RESOLVED** - Fixed paths |
| Nginx Port Conflicts | 🚨 Critical | svclb claims host ports | ✅ **RESOLVED** - NodePort service |
| MongoDB Init Job Loops | 🟡 High | Wrong MongoDB client | ✅ **RESOLVED** - Fixed client paths |
| Replica Set Configuration | 🟡 High | Missing environment variables | ✅ **RESOLVED** - Added MONGODB_* vars |
| Old ReplicaSet Persistence | 🟡 High | Multiple ReplicaSets from updates | ✅ **RESOLVED** - Cleaned old RS |

### Infrastructure Setup Challenges

#### Azure VM Environment
- **Fresh VM Setup**: Required complete Docker, k3s, Helm, Nginx Ingress installation
- **Permission Issues**: kubectl config permissions needed fixing
- **Snap Compatibility**: Helm snap version caused segmentation faults

#### k3s-Specific Issues
- **Built-in Traefik**: Conflicts with custom Nginx Ingress
- **ServiceLB (svclb)**: Automatic host port claiming
- **Resource Constraints**: Single-node limitations for pod scheduling

## 🏗️ Technical Architecture Decisions

### Load Balancing Strategy
- **Hash-based routing**: `nginx.ingress.kubernetes.io/upstream-hash-by: "$$request_uri$$host"`
- **WebSocket support**: Automatic connection upgrades
- **Large file uploads**: `proxy-body-size: "0"` (unlimited)

### Database Configuration
- **Replica set enabled**: Required for Rocket.Chat high availability
- **Authentication**: Username/password configured
- **Internal service**: ClusterIP for pod-to-pod communication

### Security Considerations
- **Pod Security**: Non-root user (UID 999), read-only root filesystem
- **Network**: ClusterIP service with ingress-based external access
- **No TLS**: HTTP-only for testing (production would add TLS)

## 📈 Performance & Scalability Insights

### Resource Allocation
- **Requests**: 1Gi memory, 500m CPU per pod
- **Limits**: 2Gi memory, 1000m CPU per pod
- **Database**: 512Mi memory, 250m CPU (MongoDB)

### Load Distribution Analysis
- **Hash-based routing**: Sticky by URI+host for session consistency
- **Pod utilization**: Both pods actively serving requests
- **WebSocket handling**: Long-lived connections maintained on assigned pod

## 🔧 Operational Lessons Learned

### Deployment Best Practices

#### 1. Single-Node Multi-Pod Considerations
- **Remove anti-affinity** for single-node testing clusters
- **Use NodePort services** to avoid svclb conflicts
- **Monitor ReplicaSet count** - clean up old ones

#### 2. MongoDB Setup Requirements
- **Enable replica set** even for single MongoDB instance
- **Use correct client paths** for Bitnami images
- **Verify authentication** before Rocket.Chat startup

#### 3. Ingress Configuration
- **Hash-based routing** provides better session consistency than round-robin
- **NodePort preferred** over LoadBalancer on k3s single-node
- **Disable competing ingress** (Traefik) when using custom Nginx

### Monitoring & Troubleshooting

#### Health Verification Commands
```bash
# Pod status and distribution
kubectl get pods -l app=rocketchat -o wide

# Load balancing verification
for i in {1..10}; do
  curl -s "http://52.183.221.89/api/info?x=$i" | jq -r '.instanceId'
done

# MongoDB replica set status
kubectl exec $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}') \
  -- /opt/bitnami/mongodb/bin/mongosh --eval "rs.status()"
```

## 📋 Recommendations for Future Deployments

### For Production Multi-Pod Deployments

1. **Use multi-node clusters** to leverage pod anti-affinity
2. **Implement proper TLS/SSL** with cert-manager
3. **Add persistent volumes** for MongoDB data
4. **Configure external load balancer** (Azure Load Balancer)
5. **Implement monitoring stack** (Prometheus + Grafana)

### For Testing Single-Node Deployments

1. **Always remove pod anti-affinity** rules
2. **Use NodePort services** instead of LoadBalancer
3. **Monitor ReplicaSet cleanup** after updates
4. **Verify MongoDB client paths** for container images

## 🎯 Success Validation

### Functional Verification Checklist
- ✅ **Pod Scheduling**: 2 pods running without affinity conflicts
- ✅ **Load Balancing**: Requests distributed across pods
- ✅ **Database Connectivity**: MongoDB replica set operational
- ✅ **WebSocket Support**: Real-time features functional
- ✅ **API Health**: `/api/info` returns 200 from both pods
- ✅ **Ingress Routing**: External access working via NodePort

### Instance Identification
Each pod generates unique instance IDs for verification:
- Pod 1: `646c00b4-e775-485a-816c-72347b6e9a44`
- Pod 2: `324957db-dce5-4644-a9aa-ec0a5db3dec7`

## 📚 Documentation Updates Required

Based on this deployment experience, the following documentation needs updates:

1. **README.md**: Add Kubernetes deployment section with single-node caveats
2. **DEPLOYMENT_GUIDE.md**: Include anti-affinity removal guidance for single-node
3. **LESSONS_LEARNED.md**: Add multi-pod Kubernetes findings
4. **TROUBLESHOOTING.md**: Expand with k3s-specific issues and solutions

## 🔮 Future Considerations

### Microservices Evaluation
- **Current**: Monolithic deployment working reliably
- **Future**: Consider microservices for larger scale deployments
- **Recommendation**: Keep monolithic for simpler deployments, evaluate microservices at 3+ pods

### Load Balancing Options
- **Hash-based**: Current choice for session consistency
- **Round-robin**: Consider for stateless workloads
- **External LB**: Azure Load Balancer for production

## 📞 Support & Maintenance

### Monitoring Commands
```bash
# Quick status check
kubectl get pods -l app=rocketchat
kubectl get rs -l app=rocketchat

# Health verification
curl -s http://52.183.221.89/api/info | jq
```

### Log Analysis
```bash
# Rocket.Chat logs
kubectl logs -l app=rocketchat -f

# MongoDB logs
kubectl logs -l app=mongodb -f
```

## Conclusion

The deployment of Rocket.Chat with 2+ pods on a single-node Kubernetes cluster was successful but required overcoming significant technical challenges. The key learning is that **single-node multi-pod deployments have unique constraints** that differ from multi-node production setups, particularly around pod anti-affinity and service networking.

The final configuration provides a robust testing environment that accurately replicates production behavior while being suitable for development and demonstration purposes. All critical functionality including load balancing, database connectivity, and WebSocket support has been verified and is operational.

**Status**: ✅ **FULLY OPERATIONAL** - Ready for production testing and customer demonstrations.
