# Troubleshooting Guide

This guide helps you resolve common issues when using the Rocket.Chat Observability Stack.

## Common Issues

### 1. Invalid Reference Format Error

**Error**: `ERROR: normalizing image: normalizing name for compat API: invalid reference format`

**Root Cause**: Empty or malformed image names in `.env` file, often caused by using an empty `env.example` template.

**Solution**: 
```bash
# Copy the updated template with all required variables
cp .env.example .env

# Or run the setup script which will create it automatically
./start.sh

# Manual fix: ensure all image variables have valid values
# Edit .env and verify these variables are set:
# ROCKETCHAT_IMAGE=docker.io/rocketchat/rocket.chat:6.5.4
# MONGO_IMAGE=docker.io/bitnami/mongodb:7.0
# NATS_IMAGE=docker.io/nats:2.10-alpine
# TRAEFIK_IMAGE=docker.io/traefik:v3.1
# MONGODB_EXPORTER_IMAGE=docker.io/bitnami/mongodb-exporter:latest
```

### 2. Environment Variables Not Set

**Error**: `WARNING: The MONGO_IMAGE variable is not set. Defaulting to a blank string.`

**Solution**: 
```bash
# Make sure .env.example exists and copy it to .env
cp .env.example .env

# Or run the setup script
./start.sh
```

### 2. Docker Compose Not Found

**Error**: `docker compose: command not found`

**Solutions**:

#### Option A: Update Docker Desktop
- Download and install the latest Docker Desktop
- This includes Docker Compose v2

#### Option B: Install Docker Compose Separately
```bash
# For Linux/macOS
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# For Windows (using PowerShell)
Invoke-WebRequest -Uri "https://github.com/docker/compose/releases/latest/download/docker-compose-windows-x86_64.exe" -OutFile "docker-compose.exe"
```

#### Option C: Use Legacy Docker Compose
```bash
# Install docker-compose v1
pip install docker-compose
```

### 3. Port Already in Use

**Error**: `Bind for 0.0.0.0:3000 failed: port is already allocated`

**Solutions**:

#### Check what's using the port:
```bash
# Linux/macOS
sudo lsof -i :3000

# Windows
netstat -ano | findstr :3000
```

#### Change ports in .env:
```bash
# Edit .env file
HOST_PORT=3001          # Change Rocket.Chat port
GRAFANA_HOST_PORT=5051  # Change Grafana port
PROMETHEUS_PORT=9001    # Change Prometheus port
```

### 4. Permission Denied

**Error**: `permission denied` or `cannot connect to the Docker daemon`

**Solutions**:

#### Add user to docker group:
```bash
# Linux
sudo usermod -aG docker $USER
# Log out and back in, or run:
newgrp docker
```

#### Start Docker service:
```bash
# Linux
sudo systemctl start docker

# macOS
open -a Docker
```

### 5. Insufficient Memory

**Error**: Containers fail to start or are very slow

**Solutions**:

#### Check available memory:
```bash
# Linux/macOS
free -h

# Windows
wmic computersystem get TotalPhysicalMemory
```

#### Increase Docker memory limits:
- **Docker Desktop**: Settings → Resources → Memory (increase to 4GB+)
- **Linux**: Increase swap space or add more RAM

### 6. Disk Space Issues

**Error**: `no space left on device`

**Solutions**:

#### Clean up Docker:
```bash
# Remove unused containers, images, and volumes
./cleanup.sh all

# Or manually
docker system prune -a --volumes
```

#### Check disk space:
```bash
# Linux/macOS
df -h

# Windows
wmic logicaldisk get size,freespace,caption
```

### 7. WSL Issues (Windows)

**Error**: Docker commands not working in WSL

**Solutions**:

#### Enable WSL2:
```powershell
# In PowerShell as Administrator
wsl --set-version Ubuntu 2
```

#### Install Docker Desktop for WSL2:
- Install Docker Desktop
- Enable "Use the WSL 2 based engine"
- Enable integration with your WSL distribution

### 8. Network Issues

**Error**: `connection refused` or `timeout`

**Solutions**:

#### Check firewall settings:
- Ensure ports 3000, 5050, 9000, 8080 are not blocked
- Temporarily disable firewall for testing

#### Check Docker network:
```bash
docker network ls
docker network inspect rocketchat-observability_default
```

### 9. MongoDB Replica Set Issues

**Error**: `ERROR ==> In order to configure MongoDB replica set authentication you need to provide the MONGODB_ROOT_PASSWORD`

**Root Cause**: MongoDB container crash-looping due to incorrect replica set authentication configuration.

**Solution**:

```bash
# Stop and remove problematic MongoDB container
docker compose -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml stop mongo
docker compose -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml rm -f mongo
docker volume rm rocketchat-observability_mongo-data

# Restart the stack - the simplified configuration should work
docker compose -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml up -d
```

**Note**: The current configuration uses simplified MongoDB settings for local development without authentication, which resolves most replica set issues.

### 10. MongoDB Connection Issues

**Error**: `MongoNetworkError: connect ECONNREFUSED`

**Solutions**:

#### Wait for MongoDB to start:
```bash
# Check MongoDB status
docker logs rocketchat-observability-mongo-1

# Wait a few minutes for initial setup
```

#### Check MongoDB replica set:
```bash
# Connect to MongoDB and initialize replica set
docker exec -it rocketchat-observability-mongo-1 mongosh
rs.initiate()
```

### 10. Traefik Configuration Issues

**Error**: Services not accessible through Traefik

**Solutions**:

#### Check Traefik logs:
```bash
docker logs rocketchat-observability-traefik-1
```

#### Verify configuration:
```bash
# Test configuration
./test-setup.sh
```

## Getting Help

### 1. Check Logs
```bash
# View all logs
make logs

# View specific service logs
docker logs rocketchat-observability-rocketchat-1
docker logs rocketchat-observability-mongo-1
docker logs rocketchat-observability-traefik-1
```

### 2. Run Diagnostics
```bash
# Check system requirements
./check-requirements.sh

# Test setup
./test-setup.sh

# Validate configuration
make compose-config
```

### 3. Reset Everything
```bash
# Complete reset (removes all data)
make reset

# Or step by step
make down
./cleanup.sh all
make up
```

### 4. Common Commands
```bash
# Start fresh
make reset && make up

# Update everything
make update

# Check status
make status

# Get help
make help
```

## Still Having Issues?

1. **Check the logs**: `make logs`
2. **Run diagnostics**: `./test-setup.sh`
3. **Check system requirements**: `./check-requirements.sh`
4. **Search existing issues**: Check GitHub issues
5. **Create a new issue**: Include logs and system information

### System Information to Include
```bash
# OS and version
uname -a

# Docker version
docker --version
docker compose version

# Available memory and disk
free -h
df -h

# Docker system info
docker system df
```
