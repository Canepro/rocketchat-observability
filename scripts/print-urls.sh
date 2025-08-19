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

# Determine mapped HTTP port for Traefik entrypoint :80
HTTP_ADDR="$($COMPOSE_CMD $FILES port traefik 80 || true)"

if [[ -z "$HTTP_ADDR" ]]; then
  echo "Traefik HTTP entrypoint (80) not published. If you used demo-up, Traefik should be published." >&2
  exit 1
fi

BASE_URL="http://${HTTP_ADDR}"

RC_URL="${BASE_URL}"
if [[ -n "${DOMAIN:-}" && "$DOMAIN" != "localhost" ]]; then
  RC_URL="http://${DOMAIN}"
fi

# Grafana via path by default
GRAFANA_URL="${BASE_URL}${GRAFANA_PATH}"
if [[ -n "${GRAFANA_DOMAIN:-}" ]]; then
  GRAFANA_URL="http://${GRAFANA_DOMAIN}"
fi

printf "Rocket.Chat: %s\n" "$RC_URL"
printf "Grafana:     %s\n" "$GRAFANA_URL"