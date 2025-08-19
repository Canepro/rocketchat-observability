# Migration Guide: Engine-Agnostic Overlay Architecture

This document outlines the evolution to a production-ready, engine-agnostic developer experience with demo/production overlays and unified tooling.

## Key Features

### 1. **Engine-Agnostic Design**
- **Auto-detection**: Makefile automatically detects and uses Docker or Podman
- **Rootless-friendly**: Demo mode uses ephemeral ports to avoid conflicts
- **No docker.sock dependency**: Uses file-based Traefik configuration

### 2. **Deployment Overlays**
- **Demo overlay** (`compose.demo.yml`): Ephemeral localhost ports, always deployable
- **Production overlay** (`compose.prod.yml`): Fixed 80/443 with Let's Encrypt support  
- **NATS monitoring** (`compose.nats-exporter.yml`): Comprehensive NATS observability

### 3. **Unified Makefile Interface**
```bash
make demo-up          # Start with ephemeral ports (no conflicts)
make prod-up          # Start production-like with fixed ports
make url              # Print effective access URLs
make backup-mongo     # Create compressed MongoDB backup
make upgrade-rc       # Safely upgrade Rocket.Chat
make demo-reset       # Factory reset with confirmation
```

### 4. **Complete Observability Stack**
- **Prometheus datasource**: Auto-provisioned in Grafana
- **Curated dashboards**: Auto-downloaded for Rocket.Chat, MongoDB, Node Exporter, Traefik, NATS
- **NATS monitoring**: Added NATS Prometheus exporter with scrape configuration
- **Complete metrics**: All services instrumented and monitored

### 5. **Dynamic Configuration Management**
- **Traefik templating**: `dynamic.tmpl.yml` rendered via `envsubst` from `.env`
- **Flexible routing**: Supports both path-based (`/grafana`) and subdomain routing
- **Protocol switching**: Easy HTTP/HTTPS toggle with Let's Encrypt

## Migration Steps

### For Existing Users

1. **Backup your current configuration**:
   ```bash
   cp .env .env.backup
   ```

2. **Update to new overlay architecture**:
   ```bash
   # Stop existing services
   make down
   
   # Copy new environment template
   cp .env.example .env
   
   # Edit .env with your custom values (domains, ports, passwords, etc.)
   ```

3. **Start with new overlay system**:
   ```bash
   # Demo mode (recommended for development)
   make demo-up
   make url    # Shows actual URLs to access services
   
   # Or production mode (for staging/production)
   make prod-up
   ```

### For New Users

1. **Quick start (always works, no port conflicts)**:
   ```bash
   git clone --depth 1 https://github.com/Canepro/rocketchat-observability.git
   cd rocketchat-observability
   cp .env.example .env
   make demo-up
   make url
   ```

2. **Production-like deployment**:
   ```bash
   # Configure .env for your domain
   echo "DOMAIN=chat.example.com" >> .env
   echo "TRAEFIK_PROTOCOL=https" >> .env  
   echo "LETSENCRYPT_ENABLED=true" >> .env
   echo "LETSENCRYPT_EMAIL=you@example.com" >> .env
   make prod-up
   ```

## Benefits of New Architecture

### 1. **Developer Experience**
- **Always-deploy demo**: Ephemeral ports eliminate conflicts
- **Engine auto-detection**: Works with Docker or Podman seamlessly
- **URL discovery**: `make url` shows actual access URLs
- **Safety workflows**: Confirmation prompts for destructive operations

### 2. **Production Ready**
- **Let's Encrypt integration**: Automatic SSL certificates
- **Backup workflows**: `make backup-mongo`, `make restore-mongo`
- **Upgrade safety**: `make upgrade-rc` with automatic image pulling
- **Configuration templating**: Dynamic Traefik config from `.env`

### 3. **Operational Excellence**
- **Unified tooling**: Single Makefile interface across engines
- **Complete observability**: Pre-provisioned dashboards and datasources
- **Flexible routing**: Path-based or subdomain Grafana access
- **NATS monitoring**: Full message broker observability

### 4. **Cross-Platform**
- **Engine-agnostic**: Docker and Podman support
- **Rootless-friendly**: Demo mode works without privileged access
- **Windows support**: PowerShell and batch script compatibility
- **No docker.sock**: File-based Traefik avoids socket dependencies

## Deployment Examples

### Quick Demo (Recommended)
```bash
make demo-up          # Always works, no port conflicts
make url              # See actual URLs
```

### Production Deployment
```bash
# Configure .env for your domain
DOMAIN=chat.example.com
TRAEFIK_PROTOCOL=https
LETSENCRYPT_ENABLED=true
LETSENCRYPT_EMAIL=you@example.com

make prod-up          # Uses fixed 80/443 ports
```

### Advanced Operations
```bash
make backup-mongo                    # Create timestamped backup
# Edit .env to change ROCKETCHAT_IMAGE version
make upgrade-rc                      # Pulls new image and restarts

make demo-reset                      # Factory reset with confirmation
make render-traefik                  # Re-render dynamic config
make fetch-dashboards                # Update Grafana dashboards
```

## File Structure

```
rocketchat-observability/
├── compose.yml                      # Rocket.Chat + NATS services
├── compose.database.yml             # MongoDB + MongoDB Exporter
├── compose.monitoring.yml           # Prometheus, Grafana, Node Exporter
├── compose.traefik.yml              # Traefik reverse proxy
├── compose.demo.yml                 # Demo overlay (ephemeral ports)
├── compose.prod.yml                 # Production overlay (fixed ports)
├── compose.nats-exporter.yml        # NATS monitoring overlay
├── .env.example                     # Complete environment template
├── Makefile                         # Unified tooling interface
├── files/
│   ├── grafana/
│   │   ├── download-dashboards.sh   # Dashboard fetcher
│   │   ├── dashboards/imported/     # Auto-downloaded dashboards
│   │   └── provisioning/            # Datasources & dashboard config
│   ├── prometheus/
│   │   └── prometheus.yml           # Scrape configuration
│   └── traefik/
│       ├── dynamic.tmpl.yml         # Template for dynamic config
│       ├── http/dynamic.yml         # HTTP routing rules
│       └── https/dynamic.yml        # HTTPS routing with Let's Encrypt
├── scripts/
│   ├── print-urls.sh                # URL discovery
│   ├── render-traefik-config.sh     # Config templating
│   └── confirm.sh                   # Safety prompts
└── docs/
    ├── MIGRATION_GUIDE.md           # This guide
    └── TROUBLESHOOTING.md           # Issue resolution
```

## New Command Patterns

**Old approach** (deprecated):
```bash
docker compose -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml up -d
```

**New overlay approach**:
```bash
make demo-up      # Uses demo overlay with ephemeral ports
make prod-up      # Uses production overlay with fixed ports
make url          # Discover actual URLs
```

## Migration Benefits

1. **Zero conflicts**: Demo mode always works regardless of existing services
2. **Production ready**: Built-in Let's Encrypt and backup workflows
3. **Engine agnostic**: Seamless Docker/Podman switching
4. **URL discovery**: No more guessing ports or domains
5. **Safety first**: Confirmation prompts and backup workflows
6. **Complete observability**: Pre-configured dashboards and metrics

## Support

- **Primary documentation**: `README.md` for complete usage guide
- **Environment configuration**: `.env.example` shows all available options  
- **Troubleshooting**: `docs/TROUBLESHOOTING.md` for common issues
- **Help command**: `make help` shows all available targets
- **URL discovery**: `make url` shows actual service URLs
