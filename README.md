# Rocket.Chat + MongoDB + Prometheus + Grafana + Traefik - Production Stack

[![Compose Lint](https://github.com/Canepro/rocketchat-observability/actions/workflows/compose-lint.yml/badge.svg)](https://github.com/Canepro/rocketchat-observability/actions/workflows/compose-lint.yml)

A production-ready, turnkey stack with complete observability and monitoring. Perfect for demos, testing, and production workloads.

## 📋 Documentation

- **[Deployment Guide](docs/DEPLOYMENT_GUIDE.md)** - Complete guide for demo, production, and cloud deployments
- **[Migration Guide](docs/MIGRATION_GUIDE.md)** - Upgrade from older versions and understand the new overlay architecture
- **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** - Common issues and solutions with overlay-specific scenarios
- **[Lessons Learned](docs/LESSONS_LEARNED.md)** - Journey from debugging hell to one-click deployment, architecture decisions and improvements

## 📖 Table of Contents

- [Rocket.Chat + MongoDB + Prometheus + Grafana + Traefik - Production Stack](#rocketchat--mongodb--prometheus--grafana--traefik---production-stack)
  - [📋 Documentation](#-documentation)
  - [📖 Table of Contents](#-table-of-contents)
  - [✨ Highlights](#-highlights)
  - [🚀 Quick Start](#-quick-start)
    - [Local Development](#local-development)
    - [Azure VM Production Deployment](#azure-vm-production-deployment)
  - [Engine-agnostic design](#engine-agnostic-design)
  - [Files overview](#files-overview)
  - [Configuration (.env)](#configuration-env)
    - [Key configuration options:](#key-configuration-options)
  - [Modes](#modes)
  - [Observability](#observability)
  - [Traefik routing](#traefik-routing)
  - [Resetting or completely cleaning a demo](#resetting-or-completely-cleaning-a-demo)
  - [Backing up and restoring Rocket.Chat data (MongoDB)](#backing-up-and-restoring-rocketchat-data-mongodb)
  - [Upgrading Rocket.Chat](#upgrading-rocketchat)
  - [🛠️ Built-in Validation & Health Monitoring](#️-built-in-validation--health-monitoring)
    - [Pre-deployment validation](#pre-deployment-validation)
    - [Health monitoring during startup](#health-monitoring-during-startup)
  - [Common tasks](#common-tasks)
  - [Security notes (production)](#security-notes-production)
  - [📖 Additional Documentation](#-additional-documentation)
  - [🤝 Contributing](#-contributing)
  - [📚 See Also](#-see-also)

## ✨ Highlights

- **Production-Ready**: Complete observability stack with monitoring, logging, and health checks
- **True One-Click Deploy**: Automated validation, health checks, and URL discovery
- **Bulletproof Reliability**: Systematic fixes for MongoDB replica sets, Traefik health checks, and Grafana configuration
- **Beautiful Visual Experience**: Enhanced UX with progress indicators, color-coded output, and professional deployment feedback
- **Engine-agnostic**: Works on Docker or Podman (rootless or rootful)
- **Unified runtime detection**: Shared script ensures consistent Docker/Podman handling
- **Zero port conflicts**: Demo overlay uses ephemeral ports automatically
- **Production-ready**: File-provider Traefik (no docker.sock), single edge for all apps
- **Complete observability**: Rocket.Chat, MongoDB, Node Exporter, Traefik, and NATS metrics
- **Pre-configured dashboards**: Grafana with curated dashboards and datasources
- **Smart defaults**: Path-based Grafana access, validated configuration
- **Comprehensive Documentation**: Detailed troubleshooting guide with focus on common domain configuration issues

## 🚀 Quick Start

### Demo Mode (One-Click Setup)

For immediate testing and development:

```bash
# 1. Clone the repository
git clone <your-repo-url>
cd rocketchat-observability

# 2. Start the demo stack (no configuration needed)
./start.sh  # runs requirements check and delegates to Makefile

# Or use the Makefile directly
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

### Production Deployment

For production deployments, see the comprehensive **[Deployment Guide](docs/DEPLOYMENT_GUIDE.md)**.

**Quick Production Setup:**
```bash
# 1. Clone and configure
git clone <your-repo-url>
cd rocketchat-observability
cp env.example .env

# 2. Edit .env with your production values
nano .env

# 3. Deploy production stack
make prod-up
```

**Production Prerequisites:**
- Domain name pointing to your server
- Server with Docker/Podman installed
- Ports 80, 443 open on firewall
- SSL certificate (Let's Encrypt auto-configured)

## 🌐 **Domain Configuration (Important!)**

**For local testing**: Default `DOMAIN=localhost` works perfectly.

**For remote access** (VPS, cloud, team access): **MUST** update domain settings:

```bash
# Edit .env file
nano .env

# Change this line:
DOMAIN=localhost

# To your server's public IP or domain:
DOMAIN=192.168.1.100     # Local network IP
DOMAIN=203.0.113.10      # Public server IP  
DOMAIN=myserver.com      # Your domain name
```

💡 **Why this matters**: Traefik routes requests based on the `DOMAIN` setting. Wrong domain = 404 errors!

**Quick domain fix for existing deployment:**
```bash
# Update domain and restart
sed -i 's/DOMAIN=localhost/DOMAIN=YOUR_IP_HERE/' .env
make down && make demo-up
```

## 🆘 **Getting 404 Errors?**

**Most common issue**: Wrong `DOMAIN` setting in `.env` file.

The deployment health checks pass but you get 404 when accessing services? This means:
- ✅ All services are running correctly
- ❌ Traefik has no route for your access method

**Quick diagnosis**:
```bash
# Check what domain Traefik is configured for:
grep DOMAIN .env

# Test localhost (should work):
curl -I http://localhost

# Test your IP (might fail if DOMAIN=localhost):
curl -I http://YOUR_SERVER_IP
```

💡 **Solution**: Update `DOMAIN` to match how you access the server, then restart.

📖 **More help**: [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md)

---

## 🌐 Deploy to Azure Container Apps (ACA)

A production-ready, single-region ACA deployment is included. It uses a single public ingress on `rocketchat` and keeps `grafana` internal (served via `/grafana` path).

### Prerequisites
- Azure CLI logged in on a machine that can access your subscription
- Resource group: `Rocketchat_RG` (existing is fine)

### One-command deploy
```bash
# From repo root
export GRAFANA_ADMIN_PASSWORD='<YOUR_GRAFANA_ADMIN_PASSWORD>'
./azure/deploy-aca.sh
```
This will:
- Deploy `azure/main.bicep` to `uksouth`
- Create/resolve ACR and import required images
- Run the one-time MongoDB init Job
- Try to add the `/grafana` route to the internal Grafana app
- Print the public FQDN for Rocket.Chat

### DNS (Cloudflare)
- Create a CNAME: `chat.canepro.me` → printed ACA FQDN (orange-cloud/proxied OK)

### Notes
- Path-based routing lives on the `rocketchat` app. If your CLI doesn’t support HTTP routes yet, add the route in Azure Portal after deploy.
- Grafana’s admin password is stored as an ACA secret.
- Node Exporter is intentionally omitted (not applicable to serverless).

---

**To stop:**
```bash
make down
```

## Engine-agnostic design

- Works with both Docker and Podman; the Makefile auto-detects the engine.
- No dependency on provider sockets (no docker.sock exposure).
- Rootless-friendly: the demo overlay binds Traefik to random free localhost ports.

## Files overview

- compose.yml, compose.database.yml, compose.monitoring.yml, compose.traefik.yml (base stack)
- compose.demo.yml (ephemeral ports for Traefik)
- compose.prod.yml (fixed 80/443, prod-like)
- compose.nats-exporter.yml (NATS exporter added)
- files/prometheus/prometheus.yml (scrape jobs)
- files/grafana/provisioning/... (datasource and dashboards provisioning)
- files/grafana/download-dashboards.sh (curated dashboards fetcher)
- files/traefik/dynamic.tmpl.yml → rendered to files/traefik/dynamic.yml
- scripts/print-urls.sh (discover effective URLs)
- scripts/render-traefik-config.sh (templating for Traefik dynamic config)
- scripts/confirm.sh (safety prompt for destructive tasks)
- Makefile (unified UX across Docker/Podman, with cleanup and upgrade flows)

## Configuration (.env)

**Automatic validation ensures your configuration works before deployment.**

Our systematic reliability improvements include:
- ✅ **MongoDB replica set auto-repair** - No more manual `rs.initiate()` needed
- ✅ **Traefik health checks** - Uses correct endpoints, no more timeouts
- ✅ **Grafana configuration** - Fixed redirect loops with proper subpath settings
- ✅ **Enhanced error messages** - Helpful tips for domain configuration issues

Run validation anytime:
```bash
make validate-env
```

### Key configuration options:

```dotenv
# Basic settings (required)
DOMAIN=localhost               # your domain/IP for production
ROOT_URL=http://localhost      # must match DOMAIN protocol

# Grafana access (choose one)
GRAFANA_PATH=/grafana          # ✅ RECOMMENDED: Simple path-based access
GRAFANA_DOMAIN=                # Leave empty for path mode
# GRAFANA_DOMAIN=grafana.example.com  # Alternative: subdomain mode (advanced)

# Production settings
TRAEFIK_PROTOCOL=http          # use https in production
LETSENCRYPT_ENABLED=           # set to true with https in production
LETSENCRYPT_EMAIL=             # your email for ACME
GRAFANA_ADMIN_PASSWORD=rc-admin
```

## Modes

- Demo (always-deploy): ephemeral ports, http
  ```bash
  make demo-up
  make url
  ```
- Prod-like: 80/443, https, Let's Encrypt
  ```bash
  # In .env:
  # TRAEFIK_PROTOCOL=https
  # LETSENCRYPT_ENABLED=true
  # LETSENCRYPT_EMAIL=you@example.com
  # DOMAIN=your.domain
  make prod-up
  ```

## Observability

Prometheus scrapes:
- Prometheus: http://prometheus:9090
- Node Exporter: http://node-exporter:9100
- MongoDB Exporter: http://mongodb-exporter:9216
- Rocket.Chat: http://rocketchat:9458
- Traefik: http://traefik:9096
- NATS Exporter: http://nats-exporter:7777

Grafana:
- Pre-provisioned Prometheus datasource
- Dashboards auto-downloaded: Prometheus overview, Node Exporter Full, Traefik v2, Rocket.Chat, NATS, MongoDB exporter
- Files: `files/grafana/provisioning/...`, dashboards under `files/grafana/dashboards/imported/...`

Update dashboards:
```bash
make fetch-dashboards
```

## Traefik routing

- Provider: file (no docker labels required).
- Dynamic config is templated from `.env`:
  - Host(`${DOMAIN}`) → Rocket.Chat
  - Host(`${DOMAIN}`) && PathPrefix(`${GRAFANA_PATH}`) → Grafana (path mode)
  - Host(`${GRAFANA_DOMAIN}`) → Grafana (subdomain mode)

Render config:
```bash
make render-traefik
```

Note: Ensure your static Traefik configuration (compose.traefik.yml) defines entryPoints `web` and optionally `websecure`, and enables the file provider pointing to `files/traefik/dynamic.yml`.

## Resetting or completely cleaning a demo

Use these when you want to get back to a pristine "first run" state.

- Safe cleanup (keep data volumes):
  ```bash
  make down
  make clean
  ```
  This stops containers and removes generated files (e.g., rendered Traefik config, imported dashboards) but preserves MongoDB, Grafana, Prometheus data.

- Factory reset demo (delete demo volumes):
  ```bash
  make demo-reset
  ```
  You'll be prompted to type YES. This stops the demo stack and deletes associated volumes, then removes generated files. Next `make demo-up` will start a fresh, empty workspace.

- Aggressive cleanup (cover demo/prod overlays):
  ```bash
  make nuke
  ```
  Similar to `demo-reset` but runs down -v using both demo and prod overlays to ensure all project volumes are removed.

Tip: After a reset, run:
```bash
make bootstrap
make demo-up
make url
```

## Backing up and restoring Rocket.Chat data (MongoDB)

Always back up before upgrading.

- Create a compressed backup:
  ```bash
  make backup-mongo
  # => backups/mongo/mongo-YYYYmmdd-HHMMSS.archive.gz
  ```

- Restore from a backup:
  ```bash
  make restore-mongo FILE=backups/mongo-YYYYmmdd-HHMMSS.archive.gz
  ```
  This stops Rocket.Chat, restores MongoDB with --drop, then starts Rocket.Chat again.

Notes:
- If your MongoDB requires auth, adjust the Makefile or provide a proper URI; the demo setup is authless.
- Ensure sufficient disk space for the dump/restore.

## Upgrading Rocket.Chat

General approach:
1) Backup:
   ```bash
   make backup-mongo
   ```
2) Review Rocket.Chat release notes and ensure MongoDB compatibility for your target version.
3) Update the Rocket.Chat image tag used by your compose:
   - Preferred: set it in `.env` (e.g., ROCKETCHAT_IMAGE=rocketchat/rocket.chat:6.9.0) if your compose references it.
   - Or edit `compose.yml` to change the `image:` tag for the `rocketchat` service.
4) Pull and restart only Rocket.Chat:
   ```bash
   make upgrade-rc
   ```
5) Verify:
   - Watch logs until startup completes:
     ```bash
     make logs
     ```
   - Sign in to the workspace and confirm the version in Admin.
   - Ensure metrics (http://rocketchat:9458 inside the network) and key functions work.

Rollback plan:
- Revert the image tag (in `.env` or compose.yml) to the previous version.
- `make upgrade-rc` to pull and restart.
- If needed, `make restore-mongo FILE=...` to restore the pre-upgrade backup.

Best practices:
- Upgrade one major version at a time when required by Rocket.Chat's migration guide.
- Avoid upgrading during peak use; schedule downtime or use maintenance mode.
- Keep MongoDB within Rocket.Chat's supported version range for your target release.

## 🛠️ Built-in Validation & Health Monitoring

### Pre-deployment validation
```bash
make validate-env               # Validate configuration before deployment
```

**Automatically checks:**
- ✅ Required environment variables are set
- ✅ No conflicting Grafana configuration (subdomain vs path)
- ✅ Valid URL formats
- ✅ Docker/Podman runtime availability
- ✅ Common misconfigurations (double paths, etc.)

### Health monitoring during startup
When you run `make demo-up` or `make prod-up`, the system provides a **beautiful, professional deployment experience**:

1. **Validates configuration** before starting (Docker access, environment variables)
2. **Renders dynamic configs** (Traefik routing based on your domain)
3. **Fetches dashboards** (Grafana provisioning with curated dashboards)
4. **Starts services** with proper dependencies
5. **Monitors health with visual progress**:
   ```
   🔄 Waiting for services to become healthy (timeout: 600s)
   ╭─────────────────────────────────────────────────────╮
   │  Please wait while we verify all services...        │
   ╰─────────────────────────────────────────────────────╯
   
   ⏳ [1/4] Checking MongoDB and replica set...
       ✅ MongoDB is ready
   ⏳ [2/4] Checking Traefik reverse proxy...
       ✅ Traefik is healthy (dashboard: http://localhost:8080/dashboard/)
   ⏳ [3/4] Checking Rocket.Chat application...
       ✅ Rocket.Chat is healthy  
   ⏳ [4/4] Checking Grafana monitoring dashboard...
       ✅ Grafana is healthy
   
   🎉 All services are healthy!
   ```
6. **Displays access URLs** when ready with proper domain routing
7. **Provides helpful tips** if issues occur (especially domain configuration)

**Enterprise-quality deployment experience** - no more guessing if services are ready! 🚀

## Common tasks

- Validate configuration:
  ```bash
  make validate-env
  ```
- Show merged config:
  ```bash
  make compose-config
  ```
- Tail logs:
  ```bash
  make logs
  ```
- See services:
  ```bash
  make ps
  ```

## Security notes (production)

- Use `TRAEFIK_PROTOCOL=https` and Let's Encrypt.
- Set secure Grafana admin password and consider SSO/integrations.
- Restrict Traefik dashboard (if enabled) and disable in public contexts.
- Harden MongoDB auth and network policies if deploying beyond lab/demo.

## 📖 Additional Documentation

- **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** ⭐ - **Start here for 404 errors!** Domain configuration and common deployment issues
- **[Migration Guide](docs/MIGRATION_GUIDE.md)** - Comprehensive guide for upgrading and understanding the overlay architecture  
- **[Lessons Learned](docs/LESSONS_LEARNED.md)** - Complete journey from debugging hell to enterprise-quality deployment, plus future nginx support plans
- **[Makefile Reference](Makefile)** - Complete list of available commands with `make help`

💡 **Quick Help**: Most deployment issues are domain-related. See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for instant solutions!

## 🚀 Future Enhancements

### nginx Support for Production (Planned)
**Coming in next major release** - Alternative to Traefik for organizations preferring nginx:
- ✅ **Same one-click deployment experience**
- ✅ **Enterprise-familiar nginx configuration**  
- ✅ **Advanced caching and performance tuning**
- ✅ **Easy migration from Traefik setup**

See detailed implementation plan in [docs/LESSONS_LEARNED.md](docs/LESSONS_LEARNED.md#nginx-support-for-production-deployments)

## 🤝 Contributing

- Issues and feature requests: [GitHub Issues](https://github.com/Canepro/rocketchat-observability/issues)
- Pull requests welcome for improvements and bug fixes
- Ensure `make compose-config` passes before submitting PRs

## 📚 See Also

- **[Lessons Learned](docs/LESSONS_LEARNED.md)** - Comprehensive analysis of the transformation from deployment issues to one-click deployment, including root cause analysis, solutions implemented, and architecture decisions

---

Happy chatting and observing! 🚀