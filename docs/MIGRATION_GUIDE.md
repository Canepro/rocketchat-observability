# Migration Guide: Aligning with Official Rocket.Chat Compose Structure

This document outlines the changes made to align this repository with the official [Rocket.Chat compose repository](https://github.com/RocketChat/rocketchat-compose) while maintaining the observability objectives.

## Key Changes Made

### 1. **Modular Compose Files**
- **Before**: Single monolithic `docker-compose.yml` file
- **After**: Separated into modular files:
  - `compose.database.yml` - MongoDB and MongoDB Exporter
  - `compose.monitoring.yml` - Prometheus, Grafana, Node Exporter, NATS, NATS Exporter
  - `compose.traefik.yml` - Traefik reverse proxy
  - `compose.yml` - Rocket.Chat application

### 2. **Environment Configuration**
- **Added**: `.env.example` file with comprehensive configuration options
- **Improved**: Better variable organization and documentation
- **Enhanced**: Support for both HTTP and HTTPS configurations

### 3. **Traefik Configuration**
- **Added**: Dynamic configuration files in `files/traefik_config/`
  - `http/dynamic.yml` - HTTP routing configuration
  - `https/dynamic.yml` - HTTPS routing with Let's Encrypt support
- **Enhanced**: Proper service discovery and routing rules

### 4. **Monitoring Improvements**
- **Added**: NATS Exporter configuration in Prometheus
- **Enhanced**: Complete metrics collection from all services
- **Improved**: Better service isolation and modularity

## Migration Steps

### For Existing Users

1. **Backup your current configuration**:
   ```bash
   cp .env .env.backup
   ```

2. **Update to new structure**:
   ```bash
   # Stop existing services
   docker compose down
   
   # Copy new environment template
   cp .env.example .env
   
   # Edit .env with your custom values
   # (ports, passwords, domains, etc.)
   ```

3. **Start with new modular structure**:
   ```bash
   docker compose -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml up -d
   ```

### For New Users

1. **Clone and setup**:
   ```bash
   git clone https://github.com/Canepro/rocketchat-observability.git
   cd rocketchat-observability
   cp .env.example .env
   # Edit .env as needed
   ```

2. **Start the stack**:
   ```bash
   docker compose -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml up -d
   ```

## Benefits of New Structure

### 1. **Newbie-Friendly**
- **One-click deployment** with `./start.sh` or `start.bat`
- **Auto-detection** of Docker/Podman
- **Smart Makefile** with helpful commands
- **Requirements checker** to validate system
- **Clear error messages** and guidance

### 2. **Flexibility**
- Deploy only needed components
- Easy to exclude monitoring or database services
- Customizable routing configurations

### 3. **Maintainability**
- Clear separation of concerns
- Easier to update individual components
- Better configuration management

### 4. **Production Ready**
- Proper Traefik configuration
- Let's Encrypt support
- Enhanced security options

### 5. **Observability**
- Complete metrics collection
- NATS monitoring added
- Better service isolation

### 6. **Cross-Platform**
- Works with Docker and Podman
- Windows batch file support
- Linux/macOS shell script support

## Custom Deployment Examples

### Minimal Setup (Rocket.Chat + Traefik only)
```bash
docker compose -f compose.traefik.yml -f compose.yml up -d
```

### With Database (no monitoring)
```bash
docker compose -f compose.database.yml -f compose.traefik.yml -f compose.yml up -d
```

### Full Stack (recommended)
```bash
docker compose -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml up -d
```

## File Structure

```
rocketchat-observability/
├── compose.database.yml      # MongoDB services
├── compose.monitoring.yml    # Monitoring stack
├── compose.traefik.yml       # Reverse proxy
├── compose.yml              # Rocket.Chat app
├── .env.example             # Environment template
├── prometheus.yml           # Prometheus config
├── files/
│   └── traefik_config/
│       ├── http/
│       │   └── dynamic.yml  # HTTP routing
│       └── https/
│           └── dynamic.yml  # HTTPS routing
├── Makefile                 # Build automation
└── README.md               # Documentation
```

## Breaking Changes

1. **Command syntax changed**: Must specify all compose files
2. **Environment variables**: Some new variables added
3. **Traefik configuration**: Now uses dynamic configuration files
4. **Service discovery**: Improved but requires proper configuration

## Support

- Check the [official Rocket.Chat compose repository](https://github.com/RocketChat/rocketchat-compose) for reference
- Review the `.env.example` file for all available configuration options
- Use the Makefile for common operations: `make up`, `make down`, `make logs`
