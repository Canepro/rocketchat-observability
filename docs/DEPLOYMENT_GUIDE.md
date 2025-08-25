# Rocket.Chat Observability - Deployment Guide

This guide covers deploying the Rocket.Chat observability stack in different environments.

## Quick Start (Demo Mode)

For immediate testing and development:

```bash
# 1. Clone the repository
git clone <your-repo-url>
cd rocketchat-observability

# 2. Start the demo stack (one-command setup)
./start.sh

# Or use the Makefile
make demo-up
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

#### 2. Deploy the Stack

```bash
# Clone the repository
git clone <your-repo-url>
cd rocketchat-observability

# Copy and configure environment
cp env.example .env
nano .env  # Edit with your production values
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

#### 5. Post-Deployment Security

```bash
# Set up firewall (Ubuntu/Debian)
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443

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

For Kubernetes deployment, see the `k8s/` directory (if available).

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
