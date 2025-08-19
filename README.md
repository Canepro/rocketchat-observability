# Rocket.Chat + MongoDB + Prometheus + Grafana + Traefik - Reference Stack

[![Compose Lint](https://github.com/Canepro/rocketchat-observability/actions/workflows/compose-lint.yml/badge.svg)](https://github.com/Canepro/rocketchat-observability/actions/workflows/compose-lint.yml)

A turnkey, reproducible local/lab stack with complete observability and a clean path to production.

## 📋 Documentation

- **[Migration Guide](docs/MIGRATION_GUIDE.md)** - Upgrade from older versions and understand the new overlay architecture
- **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** - Common issues and solutions with overlay-specific scenarios

## 📖 Table of Contents

- [Rocket.Chat + MongoDB + Prometheus + Grafana + Traefik - Reference Stack](#rocketchat--mongodb--prometheus--grafana--traefik---reference-stack)
  - [📋 Documentation](#-documentation)
  - [📖 Table of Contents](#-table-of-contents)
  - [✨ Highlights](#-highlights)
  - [Quick start (TL;DR)](#quick-start-tldr)
    - [🚀 **TRUE ONE-CLICK DEPLOY**](#-true-one-click-deploy)
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
  - [🛠️ Built-in Validation \& Health Monitoring](#️-built-in-validation--health-monitoring)
    - [Pre-deployment validation](#pre-deployment-validation)
    - [Health monitoring during startup](#health-monitoring-during-startup)
  - [Common tasks](#common-tasks)
  - [Security notes (production)](#security-notes-production)
  - [📖 Additional Documentation](#-additional-documentation)
  - [🤝 Contributing](#-contributing)

## ✨ Highlights

- **True One-Click Deploy**: Automated validation, health checks, and URL discovery
- **Engine-agnostic**: Works on Docker or Podman (rootless or rootful)
- **Zero port conflicts**: Demo overlay uses ephemeral ports automatically
- **Production-ready**: File-provider Traefik (no docker.sock), single edge for all apps
- **Complete observability**: Rocket.Chat, MongoDB, Node Exporter, Traefik, and NATS metrics
- **Pre-configured dashboards**: Grafana with curated dashboards and datasources
- **Smart defaults**: Path-based Grafana access, validated configuration

## Quick start (TL;DR)

### 🚀 **TRUE ONE-CLICK DEPLOY**

1) **Install Docker (if needed):**
```bash
curl -L https://get.docker.com | sh
```

2) **Deploy the stack:**
```bash
git clone --depth 1 https://github.com/Canepro/rocketchat-observability.git
cd rocketchat-observability
cp env.example .env          # Edit DOMAIN=your-ip if needed
make demo-up                 # Everything validates, deploys, and shows URLs!
```

**Example output:**
```
🔍 Validating environment configuration...
✅ Environment validation passed!
🔄 Rendering Traefik config...
📥 Fetching Grafana dashboards...
🚀 Starting services...
⏳ Waiting for services to start...
✅ MongoDB is ready
✅ Traefik is healthy  
✅ Rocket.Chat is ready
✅ Grafana is healthy
🎉 All services are healthy!

🌐 Your Rocket.Chat Observability Stack:
Rocket.Chat: http://localhost:32768
Grafana: http://localhost:32768/grafana
```

3) **Access your services:**
- **Rocket.Chat**: Open the Rocket.Chat URL (create admin account on first visit)
- **Grafana**: Login with user `admin`, password `rc-admin` (or your custom password from `.env`)

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
When you run `make demo-up` or `make prod-up`, the system automatically:

1. **Validates configuration** before starting
2. **Renders dynamic configs** (Traefik routing)
3. **Fetches dashboards** (Grafana provisioning)
4. **Starts services** with proper dependencies
5. **Waits for health checks** on all services
6. **Displays access URLs** when ready

No more guessing if services are ready! 🎉

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

- **[Migration Guide](docs/MIGRATION_GUIDE.md)** - Comprehensive guide for upgrading and understanding the overlay architecture
- **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** - Solutions for common issues, engine-specific problems, and overlay troubleshooting
- **[Makefile Reference](Makefile)** - Complete list of available commands with `make help`

## 🤝 Contributing

- Issues and feature requests: [GitHub Issues](https://github.com/Canepro/rocketchat-observability/issues)
- Pull requests welcome for improvements and bug fixes
- Ensure `make compose-config` passes before submitting PRs

---

Happy chatting and observing! 🚀