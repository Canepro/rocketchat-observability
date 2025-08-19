#!/usr/bin/env bash
set -euo pipefail

# Usage: scripts/print-urls.sh "<compose_cmd>" "<files...>"
# Example: scripts/print-urls.sh "docker compose" "-f compose.monitoring.yml -f compose.traefik.yml -f compose.database.yml -f compose.yml -f compose.demo.yml"

COMPOSE_CMD="${1:-}"
FILES="${2:-}"

if [[ -z "$COMPOSE_CMD" || -z "$FILES" ]]; then
  echo "Usage: scripts/print-urls.sh \"docker compose|podman compose\" \"-f ...\"" >&2
  exit 1
fi

# Load .env if present
if [[ -f .env ]]; then
  # shellcheck disable=SC2046
  export $(grep -v '^\s*#' .env | grep -E '^(DOMAIN|GRAFANA_PATH|GRAFANA_DOMAIN|TRAEFIK_PROTOCOL)=' | xargs -d '\n' -r)
fi

GRAFANA_PATH="${GRAFANA_PATH:-/grafana}"
DOMAIN="${DOMAIN:-localhost}"

# Try to find Traefik port using docker directly (more reliable)
HTTP_ADDR=""

# First try: look for published port 80 on traefik container
if command -v docker >/dev/null 2>&1; then
  # Find traefik container and get port mapping
  TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format "{{.Names}}" | head -1)
  if [[ -n "$TRAEFIK_CONTAINER" ]]; then
    HTTP_ADDR=$(docker port "$TRAEFIK_CONTAINER" 80 2>/dev/null | head -1 || true)
  fi
fi

# Fallback: try using compose command
if [[ -z "$HTTP_ADDR" ]]; then
  HTTP_ADDR="$($COMPOSE_CMD $FILES port traefik 80 2>/dev/null || true)"
fi

# If still no luck, assume localhost:80 (production mode)
if [[ -z "$HTTP_ADDR" ]]; then
  HTTP_ADDR="localhost:80"
  echo "Warning: Could not detect Traefik port, assuming localhost:80" >&2
fi

# Normalize 0.0.0.0 to localhost for user-friendly display
DISPLAY_ADDR="$HTTP_ADDR"
if [[ "$DISPLAY_ADDR" == 0.0.0.0:* ]]; then
  DISPLAY_ADDR="localhost:${DISPLAY_ADDR#0.0.0.0:}"
fi

BASE_URL="http://${DISPLAY_ADDR}"

RC_URL="${BASE_URL}"
if [[ -n "${DOMAIN:-}" && "$DOMAIN" != "localhost" ]]; then
  RC_URL="http://${DOMAIN}"
fi

# Grafana URL: prefer GRAFANA_DOMAIN, then DOMAIN+path, then base URL+path
if [[ -n "${GRAFANA_DOMAIN:-}" ]]; then
  GRAFANA_URL="http://${GRAFANA_DOMAIN}"
elif [[ -n "${DOMAIN:-}" && "$DOMAIN" != "localhost" ]]; then
  GRAFANA_URL="http://${DOMAIN}${GRAFANA_PATH}"
else
  GRAFANA_URL="${BASE_URL}${GRAFANA_PATH}"
fi

printf "Rocket.Chat: %s\n" "$RC_URL"
printf "Grafana:     %s\n" "$GRAFANA_URL"