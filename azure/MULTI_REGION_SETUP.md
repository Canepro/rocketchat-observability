# 🌍 Multi-Region Container Apps Environment Setup

## 📋 Overview

This guide covers the setup of Azure Container Apps Environment with the **"Show environments in all regions"** option enabled, which provides better availability and disaster recovery capabilities.

## 🎯 Benefits of Multi-Region Setup

### ✅ **Availability**
- **Geographic redundancy**: Services available across multiple regions
- **Disaster recovery**: Automatic failover capabilities
- **Reduced latency**: Users connect to nearest region
- **Compliance**: Meet regional data residency requirements

### ✅ **Performance**
- **Global load balancing**: Traffic distributed across regions
- **CDN integration**: Cloudflare can route to optimal region
- **Reduced latency**: Faster response times for global users

### ⚠️ **Considerations**
- **Increased complexity**: More regions to manage
- **Higher costs**: Resources in multiple regions
- **Data synchronization**: Cross-region data consistency
- **Configuration management**: Consistent settings across regions

## 🏗️ **Setup Process**

### **Step 1: Enable Multi-Region Option**

When creating the Container Apps Environment in Azure Portal:

1. **Navigate to**: Container Apps Environment creation
2. **Check**: "Show environments in all regions" checkbox
3. **Select regions**: Choose primary and secondary regions
   - **Primary**: West US 2 (recommended)
   - **Secondary**: East US 2 (for redundancy)

### **Step 2: Region Selection Strategy**

```yaml
# Recommended Region Configuration
Primary Region: West US 2
  - Lower latency for US West Coast
  - Good for demo and testing
  - Cost-effective

Secondary Region: East US 2
  - Backup for disaster recovery
  - Better for US East Coast users
  - Compliance requirements

Optional Regions:
  - West Europe (EU users)
  - Southeast Asia (APAC users)
```

### **Step 3: Resource Naming Convention**

```bash
# Multi-region naming convention
Resource Group: Rocketchat_RG
Environment Name: rocketchat-env-{region}
  - rocketchat-env-westus2
  - rocketchat-env-eastus2

Container Apps:
  - rocketchat-main-{region}
  - grafana-monitoring-{region}
  - mongo-database-{region}
```

## 🔧 **Bicep Template Modifications**

### **Multi-Region Parameters**

```bicep
@description('Primary region for deployment')
param primaryRegion string = 'westus2'

@description('Secondary region for disaster recovery')
param secondaryRegion string = 'eastus2'

@description('Enable multi-region deployment')
param enableMultiRegion bool = true

@description('Regions to deploy to')
param regions array = [
  primaryRegion
  secondaryRegion
]
```

### **Loop Through Regions**

```bicep
// Deploy to multiple regions
resource containerAppsEnvironments 'Microsoft.App/managedEnvironments@2023-05-01' = [for region in regions: {
  name: 'rocketchat-env-${region}'
  location: region
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}]
```

## 🌐 **Cloudflare Integration**

### **DNS Configuration**

```yaml
# Multi-region DNS setup
A Records:
  - chat.canepro.me → Primary region IP
  - chat.canepro.me → Secondary region IP (failover)

CNAME Records:
  - west.chat.canepro.me → Primary region
  - east.chat.canepro.me → Secondary region

Load Balancing:
  - Enable Cloudflare Load Balancer
  - Configure health checks
  - Set up failover rules
```

### **Page Rules for Multi-Region**

```yaml
# Cloudflare Page Rules
Rule 1:
  URL: chat.canepro.me/*
  Settings:
    - Cache Level: Bypass
    - Origin: Primary region

Rule 2:
  URL: west.chat.canepro.me/*
  Settings:
    - Cache Level: Bypass
    - Origin: West US 2

Rule 3:
  URL: east.chat.canepro.me/*
  Settings:
    - Cache Level: Bypass
    - Origin: East US 2
```

## 📊 **Monitoring & Health Checks**

### **Azure Monitor Configuration**

```yaml
# Multi-region monitoring
Application Insights:
  - Primary region: West US 2
  - Secondary region: East US 2
  - Cross-region correlation

Alerts:
  - Region-specific health checks
  - Cross-region availability monitoring
  - Performance comparison alerts
```

### **Health Check Endpoints**

```bash
# Health check URLs for each region
Primary Region:
  - https://chat.canepro.me/health
  - https://west.chat.canepro.me/health

Secondary Region:
  - https://east.chat.canepro.me/health
  - https://chat.canepro.me/health (failover)
```

## 💰 **Cost Management**

### **Multi-Region Cost Breakdown**

```yaml
Estimated Monthly Costs:
  Primary Region (West US 2):
    - Container Apps: $40-60
    - Container Registry: $5-10
    - Log Analytics: $5-10
    - Total: $50-80

  Secondary Region (East US 2):
    - Container Apps: $40-60
    - Container Registry: $5-10
    - Log Analytics: $5-10
    - Total: $50-80

  Total Multi-Region: $100-160
  Budget: $150/month
  Status: ⚠️ Close to budget limit
```

### **Cost Optimization Strategies**

1. **Start with Single Region**
   - Deploy to primary region only
   - Monitor usage and performance
   - Add secondary region when needed

2. **Right-size Resources**
   - Optimize CPU/memory allocation
   - Use appropriate scaling rules
   - Monitor and adjust based on usage

3. **Reserved Instances**
   - Consider reserved capacity for predictable workloads
   - Plan for long-term usage patterns

## 🚀 **Deployment Strategy**

### **Phase 1: Single Region**
```bash
# Start with primary region only
./deploy.sh --region westus2 --single-region
```

### **Phase 2: Add Secondary Region**
```bash
# Add secondary region for redundancy
./deploy.sh --region eastus2 --add-region
```

### **Phase 3: Multi-Region Load Balancing**
```bash
# Configure Cloudflare load balancing
./configure-cloudflare.sh --enable-load-balancing
```

## 🔄 **Disaster Recovery**

### **Failover Configuration**

```yaml
# Automatic failover setup
Primary Region: West US 2
  - Active: 100% traffic
  - Health check: Every 30 seconds
  - Failover threshold: 3 consecutive failures

Secondary Region: East US 2
  - Standby: 0% traffic
  - Health check: Every 30 seconds
  - Activation: Automatic on primary failure
```

### **Recovery Procedures**

1. **Automatic Failover**
   - Cloudflare detects primary region failure
   - Traffic automatically routes to secondary region
   - Health checks continue monitoring

2. **Manual Failover**
   - Admin initiates manual failover
   - Traffic manually redirected
   - Primary region investigation and recovery

3. **Recovery Steps**
   - Fix issues in primary region
   - Verify health checks pass
   - Gradually restore traffic to primary
   - Monitor for stability

## 📝 **Best Practices**

### ✅ **Do's**
- Start with single region deployment
- Monitor costs closely
- Test failover procedures regularly
- Use consistent naming conventions
- Document regional configurations

### ❌ **Don'ts**
- Don't deploy to all regions initially
- Don't skip health check configuration
- Don't ignore cost monitoring
- Don't forget backup procedures
- Don't skip documentation

## 🎯 **Next Steps**

1. **Start with single region** (West US 2)
2. **Monitor performance and costs**
3. **Add secondary region** when needed
4. **Configure Cloudflare load balancing**
5. **Test disaster recovery procedures**

---

**Status**: 📋 Planning Phase  
**Priority**: Medium (after single region deployment)  
**Estimated Effort**: 2-3 days for full multi-region setup
