# 🚀 Azure Container Apps Deployment TODO

## 📋 Project Overview
Deploy RocketChat observability stack to Azure Container Apps (ACA) with Cloudflare integration and multi-region support.

**Target Domain**: `chat.canepro.me`  
**Budget**: $150/month (Visual Studio Enterprise MPN)  
**Primary Goal**: Production-ready demo environment with easy access and scalability

---

## 🏗️ **Phase 1: Azure Infrastructure Setup**

### ✅ **Azure Container Apps Environment**
- [ ] **Create Container Apps Environment**
  - [ ] Enable "Show environments in all regions" option
  - [ ] Select optimal region (West US 2 recommended)
  - [ ] Configure network isolation
  - [ ] Set up Log Analytics workspace integration

### ✅ **Resource Group & Naming**
- [ ] **Resource Group**: `Rocketchat_RG`
- [ ] **Environment Name**: `rocketchat-env-{region}`
- [ ] **Container App Names**:
  - `rocketchat-main` (external)
  - `grafana-monitoring` (external)
  - `mongo-database` (internal)
  - `nats-messaging` (internal)
  - `prometheus-metrics` (internal)
  - `mongo-exporter` (internal)
  - `nats-exporter` (internal)
  - `node-exporter` (internal)

### ✅ **Azure Container Registry (ACR)**
- [ ] **Create ACR**: `caneprochatacr{unique}`
- [ ] **Enable admin user** for image access
- [ ] **Configure image repositories**:
  - `rocketchat/rocket.chat:6.5.4`
  - `grafana/grafana:12.0.2`
  - `bitnami/mongodb:7.0`
  - `bitnami/mongodb-exporter:0.40.0`
  - `nats:2.10-alpine`
  - `natsio/prometheus-nats-exporter:0.14.0`
  - `prom/prometheus:v3.4.2`
  - `prom/node-exporter:v1.9.1`

---

## 🌐 **Phase 2: Cloudflare Configuration**

### ✅ **Domain Setup**
- [ ] **Verify domain ownership**: `chat.canepro.me`
- [ ] **Enable Cloudflare proxy** (orange cloud)
- [ ] **Configure SSL/TLS mode**: Full (strict)
- [ ] **Enable HSTS** for security

### ✅ **DNS Records**
- [ ] **A Record**: `chat.canepro.me` → Azure Container App IP
- [ ] **CNAME Record**: `grafana.chat.canepro.me` → `chat.canepro.me` (optional subdomain)
- [ ] **MX Records**: Configure if email needed
- [ ] **TXT Records**: For verification and security

### ✅ **Cloudflare Rules & Security**
- [ ] **Page Rules**:
  - `chat.canepro.me/grafana*` → Cache Level: Bypass
  - `chat.canepro.me/api*` → Cache Level: Bypass
- [ ] **Security Settings**:
  - [ ] Enable WAF (Web Application Firewall)
  - [ ] Configure rate limiting
  - [ ] Set up bot protection
  - [ ] Enable DDoS protection

### ✅ **Performance Optimization**
- [ ] **Enable Auto Minify**: JS, CSS, HTML
- [ ] **Enable Brotli compression**
- [ ] **Configure caching rules**:
  - Static assets: 1 day
  - API responses: 0 seconds
  - Grafana assets: 1 hour

---

## 🐳 **Phase 3: Container Apps Configuration**

### ✅ **RocketChat Container App**
- [ ] **Image**: `docker.io/rocketchat/rocket.chat:6.5.4`
- [ ] **Ingress**: External, port 3000
- [ ] **Environment Variables**:
  ```bash
  MONGO_URL=mongodb://mongo-database:27017/rocketchat?replicaSet=rs0
  ROOT_URL=https://chat.canepro.me
  TRANSPORTER=nats://nats-messaging:4222
  OVERWRITE_SETTING_Prometheus_Enabled=true
  OVERWRITE_SETTING_Prometheus_Port=9458
  DEPLOY_PLATFORM=container-apps
  ```
- [ ] **Scaling**: 1-3 replicas, HTTP request-based
- [ ] **Resources**: 1.0 CPU, 2.0 GiB memory

### ✅ **Grafana Container App**
- [ ] **Image**: `docker.io/grafana/grafana:12.0.2`
- [ ] **Ingress**: External, port 3000, subpath `/grafana`
- [ ] **Environment Variables**:
  ```bash
  GF_SERVER_ROOT_URL=https://chat.canepro.me/grafana
  GF_SERVER_SERVE_FROM_SUB_PATH=true
  GF_SECURITY_ADMIN_PASSWORD=rc-admin
  GF_AUTH_ANONYMOUS_ENABLED=false
  ```
- [ ] **Scaling**: 1-2 replicas
- [ ] **Resources**: 0.5 CPU, 1.0 GiB memory

### ✅ **MongoDB Container App (Internal)**
- [ ] **Image**: `docker.io/bitnami/mongodb:7.0`
- [ ] **Ingress**: Disabled (internal only)
- [ ] **Environment Variables**:
  ```bash
  ALLOW_EMPTY_PASSWORD=yes
  MONGODB_REPLICA_SET_MODE=primary
  MONGODB_REPLICA_SET_NAME=rs0
  ```
- [ ] **Scaling**: 1 replica (fixed)
- [ ] **Resources**: 1.0 CPU, 2.0 GiB memory
- [ ] **Persistent Storage**: Configure if needed

### ✅ **NATS Container App (Internal)**
- [ ] **Image**: `docker.io/nats:2.10-alpine`
- [ ] **Ingress**: Disabled (internal only)
- [ ] **Command**: `--http_port 8222`
- [ ] **Scaling**: 1 replica (fixed)
- [ ] **Resources**: 0.5 CPU, 1.0 GiB memory

### ✅ **Prometheus Container App (Internal)**
- [ ] **Image**: `docker.io/prom/prometheus:v3.4.2`
- [ ] **Ingress**: Disabled (internal only)
- [ ] **Configuration**: Mount prometheus.yml
- [ ] **Scaling**: 1 replica (fixed)
- [ ] **Resources**: 0.5 CPU, 1.0 GiB memory

### ✅ **Exporters (Internal)**
- [ ] **MongoDB Exporter**: `bitnami/mongodb-exporter:0.40.0`
- [ ] **NATS Exporter**: `natsio/prometheus-nats-exporter:0.14.0`
- [ ] **Node Exporter**: `prom/node-exporter:v1.9.1`

---

## 🔧 **Phase 4: Infrastructure as Code (Bicep)**

### ✅ **Create Bicep Templates**
- [ ] **main.bicep**: Main deployment template
- [ ] **parameters.bicep**: Parameter definitions
- [ ] **modules/**: Reusable modules
  - [ ] `container-apps.bicep`
  - [ ] `monitoring.bicep`
  - [ ] `networking.bicep`

### ✅ **Deployment Scripts**
- [ ] **deploy.sh**: Linux/macOS deployment script
- [ ] **deploy.ps1**: Windows PowerShell deployment script
- [ ] **validate.sh**: Template validation script

### ✅ **Configuration Files**
- [ ] **prometheus.yml**: Prometheus scrape configuration
- [ ] **grafana-provisioning/**: Grafana dashboards and datasources
- [ ] **environment variables**: All service configurations

---

## 🔒 **Phase 5: Security & Monitoring**

### ✅ **Azure Security**
- [ ] **Managed Identity**: Configure for secure access
- [ ] **Key Vault**: Store sensitive configuration
- [ ] **Network Security**: Container Apps Environment isolation
- [ ] **RBAC**: Proper access control

### ✅ **Monitoring Setup**
- [ ] **Azure Monitor**: Application Insights integration
- [ ] **Log Analytics**: Centralized logging
- [ ] **Alerts**: Set up monitoring alerts
- [ ] **Dashboards**: Azure Monitor dashboards

### ✅ **Backup Strategy**
- [ ] **MongoDB Backup**: Automated backup solution
- [ ] **Configuration Backup**: Infrastructure state backup
- [ ] **Disaster Recovery**: Recovery procedures

---

## 🚀 **Phase 6: Deployment & Testing**

### ✅ **Pre-deployment Checklist**
- [ ] **Azure CLI**: Install and authenticate
- [ ] **Bicep CLI**: Install and verify
- [ ] **Domain**: Verify Cloudflare configuration
- [ ] **Budget**: Confirm subscription limits

### ✅ **Deployment Steps**
- [ ] **Resource Group**: Create `Rocketchat_RG`
- [ ] **Container Registry**: Deploy ACR
- [ ] **Environment**: Create Container Apps Environment
- [ ] **Services**: Deploy all container apps
- [ ] **DNS**: Configure Cloudflare records
- [ ] **SSL**: Verify HTTPS certificates

### ✅ **Post-deployment Testing**
- [ ] **RocketChat**: Create admin account, test functionality
- [ ] **Grafana**: Login, verify dashboards
- [ ] **MongoDB**: Test database connectivity
- [ ] **Monitoring**: Verify metrics collection
- [ ] **Performance**: Load testing
- [ ] **Security**: Security scan

---

## 📊 **Phase 7: Cost Optimization**

### ✅ **Resource Optimization**
- [ ] **Right-sizing**: Optimize CPU/memory allocation
- [ ] **Scaling rules**: Fine-tune auto-scaling
- [ ] **Storage**: Optimize persistent storage usage
- [ ] **Networking**: Minimize data transfer costs

### ✅ **Monitoring Costs**
- [ ] **Budget alerts**: Set up spending alerts
- [ ] **Cost analysis**: Regular cost reviews
- [ ] **Optimization**: Continuous improvement

---

## 📚 **Phase 8: Documentation**

### ✅ **Technical Documentation**
- [ ] **Deployment Guide**: Step-by-step instructions
- [ ] **Architecture Diagram**: Visual representation
- [ ] **Configuration Guide**: Environment setup
- [ ] **Troubleshooting Guide**: Common issues and solutions

### ✅ **User Documentation**
- [ ] **Admin Guide**: RocketChat administration
- [ ] **User Guide**: End-user instructions
- [ ] **API Documentation**: Integration guide
- [ ] **Monitoring Guide**: Grafana dashboard usage

---

## 🔄 **Phase 9: Maintenance & Updates**

### ✅ **Update Strategy**
- [ ] **Image updates**: Regular security updates
- [ ] **Infrastructure updates**: Bicep template updates
- [ ] **Configuration updates**: Environment variable updates
- [ ] **Rollback procedures**: Safe update rollback

### ✅ **Monitoring & Maintenance**
- [ ] **Health checks**: Regular service health monitoring
- [ ] **Log analysis**: Regular log review
- [ ] **Performance tuning**: Continuous optimization
- [ ] **Security updates**: Regular security patches

---

## 🎯 **Success Criteria**

### ✅ **Functional Requirements**
- [ ] RocketChat accessible at `https://chat.canepro.me`
- [ ] Grafana accessible at `https://chat.canepro.me/grafana`
- [ ] All monitoring metrics collected and displayed
- [ ] MongoDB replica set properly initialized
- [ ] Auto-scaling working correctly

### ✅ **Non-Functional Requirements**
- [ ] Response time < 2 seconds for main pages
- [ ] 99.9% uptime target
- [ ] Cost within $150/month budget
- [ ] Security compliance (HTTPS, WAF, etc.)
- [ ] Easy management and monitoring

---

## 📝 **Notes & Considerations**

### 🔍 **Multi-Region Environment**
- **"Show environments in all regions"** option enables:
  - Better availability across regions
  - Potential for geo-distribution
  - Disaster recovery options
  - **Note**: May increase costs and complexity

### 🌐 **Cloudflare Integration Benefits**
- **Performance**: Global CDN and caching
- **Security**: DDoS protection and WAF
- **SSL**: Automatic SSL certificate management
- **Analytics**: Traffic and performance insights

### 💰 **Cost Management**
- **Monitor usage**: Regular cost reviews
- **Optimize resources**: Right-size containers
- **Use reserved instances**: For predictable workloads
- **Budget alerts**: Prevent overspending

---

## 🚨 **Risk Mitigation**

### ⚠️ **Potential Risks**
- **Cost overruns**: Set budget alerts and monitor usage
- **Service downtime**: Implement health checks and monitoring
- **Data loss**: Regular backups and disaster recovery
- **Security breaches**: Regular security updates and monitoring

### 🛡️ **Mitigation Strategies**
- **Automated monitoring**: Proactive issue detection
- **Regular backups**: Data protection
- **Security best practices**: Regular security reviews
- **Documentation**: Clear procedures and runbooks

---

**Last Updated**: $(date)  
**Status**: 🚧 In Progress  
**Next Milestone**: Azure Infrastructure Setup
