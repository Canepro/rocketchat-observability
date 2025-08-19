# Automatically pick docker or podman for compose commands
COMPOSE ?=
ifeq ($(COMPOSE),)
  ifeq (, $(shell which docker 2>/dev/null))
    ifeq (, $(shell which podman 2>/dev/null))
      $(error Neither Docker nor Podman found. Please install one of them.)
    else
      COMPOSE := podman compose
    endif
  else
    # Try docker compose first, fallback to docker-compose
    ifeq (, $(shell docker compose version 2>/dev/null))
      ifeq (, $(shell which docker-compose 2>/dev/null))
        COMPOSE := docker compose
      else
        COMPOSE := docker-compose
      endif
    else
      COMPOSE := docker compose
    endif
  endif
endif

ENV_FILE ?= .env

# Detect if .env exists, if not copy from example
.PHONY: setup
setup:
	@echo "🚀 Setting up Rocket.Chat Observability Stack..."
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "📋 Creating .env from template..."; \
		cp .env.example $(ENV_FILE); \
		echo "✅ .env created! Edit it if needed before running 'make up'"; \
	else \
		echo "✅ .env already exists"; \
	fi
	@echo "🔧 Detected container runtime: $(COMPOSE)"
	@echo "📖 Run 'make up' to start the stack"

.PHONY: compose-config up down ps logs status clean reset update pull-images
compose-config:
	@echo "🔍 Validating compose configuration..."
	$(COMPOSE) --env-file $(ENV_FILE) -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml config

up: setup
	@echo "🚀 Starting Rocket.Chat Observability Stack..."
	$(COMPOSE) --env-file $(ENV_FILE) -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml up -d
	@echo "✅ Stack started!"
	@echo "🌐 Access your services:"
	@echo "   • Rocket.Chat: http://localhost:3000"
	@echo "   • Grafana: http://localhost:5050 (admin/rc-admin)"
	@echo "   • Prometheus: http://127.0.0.1:9000"
	@echo "   • Traefik Dashboard: http://localhost:8080"

down:
	@echo "🛑 Stopping Rocket.Chat Observability Stack..."
	$(COMPOSE) --env-file $(ENV_FILE) -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml down --remove-orphans
	@echo "✅ Stack stopped!"

ps:
	@echo "📊 Container status:"
	$(COMPOSE) --env-file $(ENV_FILE) -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml ps

logs:
	@echo "📋 Following logs (Ctrl+C to stop):"
	$(COMPOSE) --env-file $(ENV_FILE) -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml logs -f --tail=200

status: ps
	@echo ""
	@echo "🔗 Service URLs:"
	@echo "   • Rocket.Chat: http://localhost:3000"
	@echo "   • Grafana: http://localhost:5050"
	@echo "   • Prometheus: http://127.0.0.1:9000"
	@echo "   • Traefik Dashboard: http://localhost:8080"

clean:
	@echo "🧹 Cleaning up containers and networks..."
	$(COMPOSE) --env-file $(ENV_FILE) -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml down --remove-orphans --volumes
	@echo "✅ Cleanup complete!"

reset: clean
	@echo "🔄 Full reset - removing all data..."
	@echo "⚠️  This will delete ALL data including databases!"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	$(COMPOSE) --env-file $(ENV_FILE) -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml down --remove-orphans --volumes --rmi all
	@echo "✅ Full reset complete!"

# Update commands
pull-images:
	@echo "📥 Pulling latest images..."
	$(COMPOSE) --env-file $(ENV_FILE) -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml pull
	@echo "✅ Images updated!"

update: down pull-images up
	@echo "🔄 Update complete! Stack restarted with latest images."

# Quick deployment options
.PHONY: quick-start minimal full
quick-start: up
	@echo "🎉 Quick start complete! Check the URLs above."

minimal:
	@echo "🚀 Starting minimal stack (Rocket.Chat + Traefik only)..."
	$(COMPOSE) --env-file $(ENV_FILE) -f compose.traefik.yml -f compose.yml up -d
	@echo "✅ Minimal stack started!"
	@echo "🌐 Rocket.Chat: http://localhost:3000"

full: up
	@echo "🎉 Full observability stack deployed!"

# Help target
.PHONY: help
help:
	@echo "🚀 Rocket.Chat Observability Stack - Makefile Help"
	@echo ""
	@echo "Quick Start:"
	@echo "  make setup      - Initialize environment (creates .env if missing)"
	@echo "  make up         - Start full stack (recommended for first time)"
	@echo "  make quick-start - Same as 'make up'"
	@echo ""
	@echo "Management:"
	@echo "  make down       - Stop all services"
	@echo "  make ps         - Show container status"
	@echo "  make logs       - Follow logs from all services"
	@echo "  make status     - Show status and service URLs"
	@echo ""
	@echo "Deployment Options:"
	@echo "  make minimal    - Start only Rocket.Chat + Traefik"
	@echo "  make full       - Start complete observability stack"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean      - Stop and remove containers/volumes"
	@echo "  make reset      - Full reset (removes all data and images)"
	@echo "  make update     - Update to latest images and restart"
	@echo "  make pull-images - Pull latest images without restarting"
	@echo "  make compose-config - Validate compose configuration"
	@echo ""
	@echo "Environment:"
	@echo "  ENV_FILE=.env   - Specify environment file (default: .env)"
	@echo "  COMPOSE=docker compose - Force Docker Compose"
	@echo "  COMPOSE=podman compose - Force Podman Compose"