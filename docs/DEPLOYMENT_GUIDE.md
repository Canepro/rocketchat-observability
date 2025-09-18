# Rocket.Chat Observability - Deployment Guide

This guide covers deploying the Rocket.Chat observability stack in different environments.

## 📋 Table of Contents

- [Quick Start (Demo Mode)](#quick-start-demo-mode)
- [Production Deployment](#production-deployment)
  - [Prerequisites](#prerequisites)
  - [Step-by-Step Production Setup](#step-by-step-production-setup)
- [Cloud Deployment Options](#cloud-deployment-options)
- [Port Configuration](#port-configuration)
  - [Required Ports Overview](#required-ports-overview)
  - [Port Configuration by Deployment Type](#port-configuration-by-deployment-type)
  - [Cloud Provider Firewall Configuration](#cloud-provider-firewall-configuration)
  - [Security Best Practices](#security-best-practices)
  - [Troubleshooting Port Issues](#troubleshooting-port-issues)
- [Environment-Specific Configurations](#environment-specific-configurations)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Security Checklist](#security-checklist)
- [Performance Tuning](#performance-tuning)
- [Support](#support)
- [Cost Estimation](#cost-estimation)

## Quick Start (Demo Mode)

For immediate testing and development, use the true one-click script:

```bash
curl -fsSL https://raw.githubusercontent.com/Canepro/rocketchat-observability/true-one-click/one-click-demo.sh | bash
```

**Demo Features:**
- ✅ No configuration required
- ✅ Works on any OS with Docker/Podman
- ✅ Ephemeral ports to avoid conflicts
- ✅ No authentication barriers
- ✅ Ready in ~2 minutes

**Access URLs:**
- Rocket.Chat: http://localhost:3000
- Grafana: http://localhost:5050 (admin/rc-admin)
- Prometheus: http://localhost:9090
- Traefik Dashboard: http://localhost:8080

## Production Deployment

### Prerequisites

1. **Domain Name**: Set up a domain and point it to your server
2. **Server**: Linux server with Docker/Podman installed
3. **Firewall**: Open ports 80, 443, and SSH (22)
4. **SSL Certificate**: Let's Encrypt will be configured automatically

### Step-by-Step Production Setup

#### 1. Server Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker (if not already installed)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install docker-compose-plugin -y

# Logout and login again for group changes
```

#### 2. One-Click Production Setup

Use the interactive one-click production script:

```bash
curl -fsSL https://raw.githubusercontent.com/Canepro/rocketchat-observability/true-one-click/one-click-prod.sh | bash
```

#### 3. Production Environment Configuration

Edit `.env` with these **required** production values:

```bash
# Domain and URLs
DOMAIN=your-domain.com
ROOT_URL=https://your-domain.com

# Security
GRAFANA_ADMIN_PASSWORD=your-strong-password
MONGODB_ENABLE_AUTHENTICATION=true
MONGODB_ROOT_PASSWORD=your-strong-mongo-password

# SSL/TLS
TRAEFIK_PROTOCOL=https
LETSENCRYPT_ENABLED=true
LETSENCRYPT_EMAIL=your-email@domain.com

# Traefik Dashboard Security
TRAEFIK_DASHBOARD_USER=admin
TRAEFIK_DASHBOARD_PASSWORD_HASH=$(htpasswd -nb admin yourpassword)
```

#### 4. Deploy Production Stack

```bash
# Validate configuration
make validate-env

# Deploy production stack
make prod-up

# Check status
make ps
make url
```

#### 5. Configure Firewall and Ports

**⚠️ IMPORTANT**: You must open the required ports on your cloud provider's firewall for the stack to work.

**Required Ports:**
- **22** - SSH access
- **80** - HTTP (for Let's Encrypt validation)
- **443** - HTTPS (main application traffic)
- **3000** - Rocket.Chat application
- **5050** - Grafana monitoring dashboard
- **9090** - Prometheus metrics
- **8080** - Traefik dashboard

**Quick Firewall Setup:**
```bash
# Ubuntu/Debian with UFW
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 3000
sudo ufw allow 5050
sudo ufw allow 9090
sudo ufw allow 8080

# Check status
sudo ufw status
```

**Cloud Provider Configuration:**
See the [Port Configuration](#port-configuration) section below for detailed instructions.

#### 6. Post-Deployment Security

```bash
# Set up regular backups
crontab -e
# Add: 0 2 * * * cd /path/to/rocketchat-observability && make backup-mongo
```

## Cloud Deployment Options

### Option 1: Any Cloud VM

The stack works on any cloud provider:

1. **AWS EC2**: Use Ubuntu 22.04 LTS
2. **Google Cloud**: Use Ubuntu 22.04 LTS  
3. **Azure VM**: Use Ubuntu 22.04 LTS
4. **DigitalOcean**: Use Ubuntu 22.04 LTS
5. **Vultr**: Use Ubuntu 22.04 LTS

**Recommended VM Specs:**
- **Demo**: 2GB RAM, 1 vCPU, 20GB storage
- **Production**: 4GB RAM, 2 vCPU, 50GB storage
- **High-traffic**: 8GB RAM, 4 vCPU, 100GB storage

### Option 2: Docker Hosting Services

- **Railway**: Supports Docker Compose
- **Render**: Supports Docker Compose
- **Fly.io**: Supports Docker Compose
- **DigitalOcean App Platform**: Supports Docker Compose

### Option 3: Kubernetes

For Kubernetes deployment with multiple Rocket.Chat pods, see the comprehensive `k8s/` directory which includes:

- **Multi-pod deployment**: 2+ Rocket.Chat instances with load balancing
- **Complete setup scripts**: Automated deployment with `./deploy.sh`
- **Nginx Ingress**: Hash-based load balancing configuration
- **MongoDB with replica set**: Production-ready database setup

**Key Considerations:**
- **Single-node clusters**: Remove pod anti-affinity rules
- **Load balancing**: Hash-based routing for session consistency
- **Port conflicts**: Use NodePort services on k3s

For detailed findings and challenges, see **[Multi-Pod Kubernetes Summary](../docs/MULTI_POD_DEPLOYMENT_SUMMARY.md)**.

**Quick Start:**
```bash
cd k8s
chmod +x deploy.sh
./deploy.sh deploy
./deploy.sh status
```

## Port Configuration

**⚠️ CRITICAL**: This section explains which ports need to be opened for the stack to work properly.

### Required Ports Overview

| Port | Service | Purpose | Required For |
|------|---------|---------|--------------|
| **22** | SSH | Server access | All deployments |
| **80** | HTTP | Web traffic | Production (Let's Encrypt) |
| **443** | HTTPS | Secure web traffic | Production |
| **3000** | Rocket.Chat | Main application | All deployments |
| **5050** | Grafana | Monitoring dashboard | All deployments |
| **9090** | Prometheus | Metrics collection | All deployments |
| **8080** | Traefik Dashboard | Reverse proxy management | All deployments |

### Port Configuration by Deployment Type

#### Demo Mode (Local Development)
```bash
# Uses ephemeral ports (auto-assigned by Docker)
- 127.0.0.1::80    # HTTP (random port)
- 127.0.0.1::443   # HTTPS (random port)
- 8080:8080        # Traefik Dashboard
- 9090:9090        # Prometheus
- 5050:3000        # Grafana
- 3000:3000        # Rocket.Chat
```
**Note**: Demo mode uses ephemeral ports to avoid conflicts. No firewall configuration needed for local development.

#### Production Mode (Cloud Deployment)
```bash
# Uses fixed ports (must be open on firewall)
- 0.0.0.0:80       # HTTP (for Let's Encrypt)
- 0.0.0.0:443      # HTTPS (main traffic)
- 8080:8080        # Traefik Dashboard
- 9090:9090        # Prometheus
- 5050:3000        # Grafana
- 3000:3000        # Rocket.Chat
```

### Cloud Provider Firewall Configuration

#### AWS EC2 Security Groups
```bash
# Inbound Rules (REQUIRED)
Type        Port    Source      Description
SSH         22      0.0.0.0/0   SSH access
HTTP        80      0.0.0.0/0   Web traffic
HTTPS       443     0.0.0.0/0   Secure web traffic
Custom TCP  3000    0.0.0.0/0   Rocket.Chat
Custom TCP  5050    0.0.0.0/0   Grafana
Custom TCP  9090    0.0.0.0/0   Prometheus
Custom TCP  8080    0.0.0.0/0   Traefik Dashboard

# Outbound Rules (DEFAULT - usually no action needed)
Type        Port    Destination Description
All traffic All    0.0.0.0/0   All outbound traffic
```

#### Azure VM Network Security Groups
```bash
# Inbound Security Rules (REQUIRED)
Name            Priority  Port  Protocol  Source
SSH             1000      22    TCP       *
HTTP            1001      80    TCP       *
HTTPS           1002      443   TCP       *
RocketChat      1003      3000  TCP       *
Grafana         1004      5050  TCP       *
Prometheus      1005      9090  TCP       *
Traefik         1006      8080  TCP       *

# Outbound Security Rules (DEFAULT)
Name            Priority  Port  Protocol  Destination
AllowInternet   4096      *     *         *
```

#### Google Cloud VPC Firewall
```bash
# Firewall Rules (REQUIRED)
Name                    Ports    Source Ranges
allow-ssh               22       *
allow-http              80       *
allow-https             443      *
allow-rocketchat        3000     *
allow-grafana           5050     *
allow-prometheus        9090     *
allow-traefik           8080     *
```

#### DigitalOcean Firewall
```bash
# Inbound Rules (REQUIRED)
Type    Port    Source
SSH     22      *
HTTP    80      *
HTTPS   443     *
Custom  3000    *
Custom  5050    *
Custom  9090    *
Custom  8080    *

# Outbound Rules (DEFAULT)
Type        Port    Destination
All traffic All     *
```

### Security Best Practices

#### For Production (Recommended)
```bash
# Restrict access where possible
SSH (22)     → Your IP only
HTTP (80)    → 0.0.0.0/0 (Let's Encrypt needs this)
HTTPS (443)  → 0.0.0.0/0 (Main traffic)
3000, 5050, 9090, 8080 → Admin IPs only (or VPN)
```

#### For Demo/Testing
```bash
# Open all required ports
All ports → 0.0.0.0/0
```

### Important Notes

1. **Inbound vs Outbound**: You only need to configure **INBOUND** ports. Outbound ports are typically open by default.

2. **Cloud Provider Defaults**: Most cloud providers block inbound traffic by default but allow all outbound traffic.

3. **Let's Encrypt Requirements**: Port 80 must be open for Let's Encrypt certificate validation.

4. **SSH Access**: Keep port 22 open for server management.

5. **Monitoring Ports**: Consider restricting access to monitoring ports (5050, 9090, 8080) to admin IPs only.

### Troubleshooting Port Issues

If services are not accessible:

1. **Check firewall rules** on your cloud provider
2. **Verify port configuration** in your `.env` file
3. **Test connectivity** using `telnet` or `nc`
4. **Check service status** with `make ps`
5. **Review logs** with `make logs`

```bash
# Test port connectivity
telnet your-server-ip 80
telnet your-server-ip 443
telnet your-server-ip 3000
```

## Environment-Specific Configurations

### Local Development

```bash
# Use demo overlay for development
make demo-up

# Access services locally
make url
```

### Staging Environment

```bash
# Use production overlay with staging domain
DOMAIN=staging.yourdomain.com
TRAEFIK_PROTOCOL=https
LETSENCRYPT_ENABLED=true
make prod-up
```

### Production Environment

```bash
# Full production setup with all security measures
# Follow the production deployment steps above
make prod-up
```

## Monitoring and Maintenance

### Health Checks

```bash
# Check service status
make ps

# View logs
make logs

# Check URLs
make url
```

### Backups

```bash
# Manual backup
make backup-mongo

# Restore from backup
make restore-mongo FILE=backups/mongo-20231201-120000.archive.gz
```

### Updates

```bash
# Update Rocket.Chat
make upgrade-rc

# Update all images
docker compose pull
docker compose up -d
```

### Troubleshooting

```bash
# Validate environment
make validate-env

# Check Docker/Podman access
make check-docker

# Reset demo environment
make demo-reset

# Full cleanup
make nuke
```

## Security Checklist

- [ ] Change all default passwords
- [ ] Enable MongoDB authentication
- [ ] Configure SSL/TLS certificates
- [ ] Set up firewall rules
- [ ] Enable regular backups
- [ ] Monitor system resources
- [ ] Keep system and containers updated
- [ ] Review logs regularly
- [ ] Set up monitoring alerts

## Performance Tuning

### For High Traffic

1. **Increase MongoDB resources**:
   ```yaml
   mongo:
     deploy:
       resources:
         limits:
           memory: 2G
           cpus: '1.0'
   ```

2. **Add Redis for session storage**:
   ```yaml
   redis:
     image: redis:7-alpine
     restart: unless-stopped
   ```

3. **Use external MongoDB** for production workloads

4. **Configure proper monitoring and alerting**

## Support

- **Documentation**: Check `docs/` directory
- **Troubleshooting**: See `docs/TROUBLESHOOTING.md`
- **Issues**: Report on GitHub
- **Community**: Rocket.Chat community channels

## Cost Estimation

### Cloud VM Costs (Monthly)

- **Demo/Testing**: $5-15/month
- **Small Production**: $20-50/month  
- **Medium Production**: $50-150/month
- **Large Production**: $150+/month

### Factors Affecting Cost

- VM size and specifications
- Storage requirements
- Bandwidth usage
- Backup storage
- Monitoring services

---

**Note**: This stack is designed to be cost-effective while providing enterprise-grade features. Start with demo mode to test, then scale up as needed.

## 🔓 **Required Ports for Deployment**

### **Essential Ports (Must be open):**

| Port | Service | Purpose | Required For |
|------|---------|---------|--------------|
| **22** | SSH | Server access | All deployments |
| **80** | HTTP | Web traffic | Production (Let's Encrypt) |
| **443** | HTTPS | Secure web traffic | Production |
| **3000** | Rocket.Chat | Main application | All deployments |
| **5050** | Grafana | Monitoring dashboard | All deployments |
| **9090** | Prometheus | Metrics collection | All deployments |
| **8080** | Traefik Dashboard | Reverse proxy management | All deployments |

### **Internal Ports (Container-to-container):**
- **27017** - MongoDB (internal only)
- **4222** - NATS (internal only)
- **9458** - Rocket.Chat metrics (internal only)
- **8222** - NATS HTTP (internal only)

## 🌐 **Port Configuration by Deployment Type**

### **Demo Mode (Local Development):**
```bash
# Ephemeral ports (auto-assigned by Docker)
- 127.0.0.1::80    # HTTP (random port)
- 127.0.0.1::443   # HTTPS (random port)
- 8080:8080        # Traefik Dashboard
- 9090:9090        # Prometheus
- 5050:3000        # Grafana
- 3000:3000        # Rocket.Chat
```

### **Production Mode (Cloud Deployment):**
```bash
# Fixed ports (must be open on firewall)
- 0.0.0.0:80       # HTTP (for Let's Encrypt)
- 0.0.0.0:443      # HTTPS (main traffic)
- 8080:8080        # Traefik Dashboard
- 9090:9090        # Prometheus
- 5050:3000        # Grafana
- 3000:3000        # Rocket.Chat
```

## ☁️ **Cloud Provider Firewall Configuration**

### **AWS EC2 Security Groups:**
```bash
# Inbound Rules
Type        Port    Source      Description
SSH         22      0.0.0.0/0   SSH access
HTTP        80      0.0.0.0/0   Web traffic
HTTPS       443     0.0.0.0/0   Secure web traffic
Custom TCP  3000    0.0.0.0/0   Rocket.Chat
Custom TCP  5050    0.0.0.0/0   Grafana
Custom TCP  9090    0.0.0.0/0   Prometheus
Custom TCP  8080    0.0.0.0/0   Traefik Dashboard
```

### **Azure VM Network Security Groups:**
```bash
# Inbound Security Rules
Name            Priority  Port  Protocol  Source
SSH             1000      22    TCP       *
HTTP            1001      80    TCP       *
HTTPS           1002      443   TCP       *
RocketChat      1003      3000  TCP       *
Grafana         1004      5050  TCP       *
Prometheus      1005      9090  TCP       *
Traefik         1006      8080  TCP       *
```

### **Google Cloud VPC Firewall:**
```bash
# Firewall Rules
Name                    Ports    Source Ranges
allow-ssh               22       *
allow-http              80       *
allow-https             443      *
allow-rocketchat        3000     *
allow-grafana           5050     *
allow-prometheus        9090     *
allow-traefik           8080     *
```

### **DigitalOcean Firewall:**
```bash
# Inbound Rules
Type    Port    Source
SSH     22      *
HTTP    80      *
HTTPS   443     *
Custom  3000    *
Custom  5050    *
Custom  9090    *
Custom  8080    *
```

## 🔒 **Security Recommendations**

### **For Production:**
1. **Restrict SSH (22)** to your IP only
2. **Limit monitoring ports** (5050, 9090, 8080) to admin IPs
3. **Use VPN** for admin access to monitoring ports
4. **Enable UFW/iptables** on the server:
   ```bash
   sudo ufw enable
   sudo ufw allow ssh
   sudo ufw allow 80
   sudo ufw allow 443
   sudo ufw allow from YOUR_IP to any port 3000
   sudo ufw allow from YOUR_IP to any port 5050
   sudo ufw allow from YOUR_IP to any port 9090
   sudo ufw allow from YOUR_IP to any port 8080
   ```

### **For Demo/Testing:**
- All ports can be open to `0.0.0.0/0` for easy access
- Use ephemeral ports to avoid conflicts

## 📋 **Quick Cloud Deployment Checklist:**

1. ✅ **Open ports 22, 80, 443, 3000, 5050, 9090, 8080**
2. ✅ **Configure firewall rules**
3. ✅ **Set up domain DNS pointing to server IP**
4. ✅ **Deploy with `make prod-up`**
5. ✅ **Access via HTTPS on port 443**

The key difference is that **demo mode** uses ephemeral ports (safer for local development), while **production mode** uses fixed ports that must be explicitly opened on your cloud provider's firewall.
