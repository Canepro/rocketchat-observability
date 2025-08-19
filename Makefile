# Makefile wrapper: auto-detect docker/podman, unified UX, URL printing,
# Traefik config rendering, dashboard fetching, cleanup, and upgrades.

SHELL := /usr/bin/bash
.ONESHELL:

# Detect engine and compose command
COMPOSE := $(shell \
	if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then \
		if docker compose version >/dev/null 2>&1; then \
			echo "docker compose"; \
		elif command -v docker-compose >/dev/null 2>&1; then \
			echo "docker-compose"; \
		else \
			echo "docker compose"; \
		fi; \
	elif command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then \
		echo "podman compose"; \
	else \
		echo ""; \
	fi)

ifeq ($(COMPOSE),)
$(error Neither docker nor podman is available)
endif

# Base compose files (follow Rocket.Chat compose split)
BASE_FILES := -f compose.monitoring.yml -f compose.traefik.yml -f compose.database.yml -f compose.yml

# Overlays
DEMO_OVERLAYS := -f compose.demo.yml -f compose.nats-exporter.yml
PROD_OVERLAYS := -f compose.prod.yml -f compose.nats-exporter.yml

ENV_FILE := .env

# Service names (adjust here if they differ in your compose)
MONGO_SERVICE ?= mongo
RC_SERVICE    ?= rocketchat

BACKUP_DIR    ?= backups/mongo
TIMESTAMP     := $(shell date -u +%Y%m%d-%H%M%S)

.PHONY: validate-env
validate-env:
	@chmod +x scripts/validate-env.sh
	@scripts/validate-env.sh

.PHONY: help
help:
	@echo "Targets:"
	@echo "  make validate-env     - Validate .env configuration before deployment"
	@echo "  make bootstrap        - Render Traefik config and fetch Grafana dashboards"
	@echo "  make up               - Start stack with base files"
	@echo "  make demo-up          - Start demo (ephemeral ports) + NATS exporter"
	@echo "  make prod-up          - Start prod-like (fixed 80/443) + NATS exporter"
	@echo "  make down             - Stop stack (keep volumes)"
	@echo "  make logs             - Tail logs"
	@echo "  make ps               - Show services"
	@echo "  make url              - Print effective URLs"
	@echo "  make compose-config   - Print merged compose config"
	@echo "  make fetch-dashboards - Download/refresh Grafana dashboards"
	@echo "  make render-traefik   - Render Traefik dynamic config from template"
	@echo
	@echo "Cleanup:"
	@echo "  make clean            - Remove generated files, keep data volumes"
	@echo "  make demo-reset       - Factory reset demo (down -v) and remove generated files"
	@echo "  make nuke             - Aggressive cleanup (down -v for demo and prod overlays)"
	@echo
	@echo "Backups & Upgrades:"
	@echo "  make backup-mongo     - Stream a compressed mongodump archive to backups/"
	@echo "  make restore-mongo FILE=backups/mongo-YYYYmmdd-HHMMSS.archive.gz"
	@echo "  make upgrade-rc       - Pull current RC image tag from compose and restart RC"
	@echo
	@echo "Engine: $(COMPOSE)"
	@echo "Env file: $(ENV_FILE)"
	@if [ -f "$(ENV_FILE)" ]; then \
	  GRAFANA_PASS=$$(grep -E '^GRAFANA_ADMIN_PASSWORD=' $(ENV_FILE) | cut -d= -f2-); \
	  echo "Grafana admin password: $${GRAFANA_PASS:-rc-admin}"; \
	else \
	  echo "Grafana admin password: rc-admin"; \
	fi

.PHONY: bootstrap
bootstrap: render-traefik fetch-dashboards

.PHONY: up
up: render-traefik
	$(COMPOSE) $(BASE_FILES) up -d

.PHONY: demo-up
demo-up: validate-env render-traefik fetch-dashboards
	$(COMPOSE) $(BASE_FILES) $(DEMO_OVERLAYS) up -d
	@echo "⏳ Waiting for services to start..."
	@chmod +x scripts/wait-for-services.sh
	@scripts/wait-for-services.sh
	@echo ""
	@$(MAKE) url

.PHONY: prod-up
prod-up: validate-env render-traefik fetch-dashboards
	$(COMPOSE) $(BASE_FILES) $(PROD_OVERLAYS) up -d
	@echo "⏳ Waiting for services to start..."
	@chmod +x scripts/wait-for-services.sh
	@scripts/wait-for-services.sh
	@echo ""
	@$(MAKE) url

.PHONY: down
down:
	$(COMPOSE) $(BASE_FILES) down

.PHONY: restart
restart:
	$(COMPOSE) $(BASE_FILES) restart

.PHONY: logs
logs:
	$(COMPOSE) $(BASE_FILES) logs -f --tail=200

.PHONY: ps
ps:
	$(COMPOSE) $(BASE_FILES) ps

.PHONY: compose-config
compose-config:
	$(COMPOSE) $(BASE_FILES) config

.PHONY: url urls
url urls:
	@bash scripts/print-urls.sh $(COMPOSE) "$(BASE_FILES) $(DEMO_OVERLAYS)" || \
	 bash scripts/print-urls.sh $(COMPOSE) "$(BASE_FILES) $(PROD_OVERLAYS)" || \
	 bash scripts/print-urls.sh $(COMPOSE) "$(BASE_FILES)"

.PHONY: fetch-dashboards
fetch-dashboards:
	@bash files/grafana/download-dashboards.sh files/grafana/dashboards

.PHONY: render-traefik
render-traefik:
	@bash scripts/render-traefik-config.sh

# ------------------------------
# Cleanup (safe and destructive)
# ------------------------------

.PHONY: clean
clean:
	@echo "Removing generated files (keeping data volumes)..."
	@rm -f files/traefik/dynamic.yml || true
	@rm -rf files/grafana/dashboards/imported || true
	@echo "Done."

.PHONY: demo-reset
demo-reset:
	@bash scripts/confirm.sh "Factory reset demo: this will STOP containers and DELETE all demo volumes. Type YES to proceed." || exit 1
	$(COMPOSE) $(BASE_FILES) $(DEMO_OVERLAYS) down -v --remove-orphans
	@$(MAKE) clean
	@echo "Demo reset completed."

.PHONY: nuke
nuke:
	@bash scripts/confirm.sh "NUKE: This will STOP containers and DELETE volumes for both demo and prod overlays. Type YES to proceed." || exit 1
	-$(COMPOSE) $(BASE_FILES) $(DEMO_OVERLAYS) down -v --remove-orphans || true
	-$(COMPOSE) $(BASE_FILES) $(PROD_OVERLAYS) down -v --remove-orphans || true
	@$(MAKE) clean
	@echo "Aggressive cleanup done."

# ------------------------------
# Backups & Upgrades
# ------------------------------

.PHONY: backup-mongo
backup-mongo:
	@mkdir -p "$(BACKUP_DIR)"
	@echo "Creating compressed mongodump archive from $(MONGO_SERVICE)..."
	$(COMPOSE) $(BASE_FILES) exec -T $(MONGO_SERVICE) mongodump --archive --gzip > "$(BACKUP_DIR)/mongo-$(TIMESTAMP).archive.gz"
	@echo "Backup written to $(BACKUP_DIR)/mongo-$(TIMESTAMP).archive.gz"

.PHONY: restore-mongo
restore-mongo:
	@if [ -z "$(FILE)" ]; then echo "Usage: make restore-mongo FILE=backups/mongo-YYYYmmdd-HHMMSS.archive.gz"; exit 2; fi
	@bash scripts/confirm.sh "RESTORE: This will DROP and restore MongoDB from $(FILE). Type YES to proceed." || exit 1
	@echo "Stopping Rocket.Chat to avoid writes during restore..."
	$(COMPOSE) $(BASE_FILES) stop $(RC_SERVICE)
	@echo "Restoring MongoDB..."
	cat "$(FILE)" | $(COMPOSE) $(BASE_FILES) exec -T $(MONGO_SERVICE) mongorestore --drop --archive --gzip
	@echo "Starting Rocket.Chat..."
	$(COMPOSE) $(BASE_FILES) up -d $(RC_SERVICE)
	@echo "Restore completed."

# Pull and restart Rocket.Chat with whatever tag your compose defines.
# To change versions, update your .env (e.g., ROCKETCHAT_IMAGE or RC_VERSION) or compose.yml, then run this target.
.PHONY: upgrade-rc
upgrade-rc:
	@echo "Pulling Rocket.Chat image defined in compose and restarting service..."
	$(COMPOSE) $(BASE_FILES) pull $(RC_SERVICE)
	$(COMPOSE) $(BASE_FILES) up -d $(RC_SERVICE)
	@echo "Upgrade attempted. Check logs:"
	$(COMPOSE) $(BASE_FILES) logs -f --tail=200 $(RC_SERVICE)