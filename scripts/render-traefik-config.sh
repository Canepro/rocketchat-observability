#!/usr/bin/env bash
set -euo pipefail

# Renders files/traefik/dynamic.tmpl.yml -> files/traefik/dynamic.yml using envsubst.

if ! command -v envsubst >/dev/null 2>&1; then
  echo "envsubst is required. Install gettext-base (Debian/Ubuntu) or gettext (RHEL/Fedora) and retry." >&2
  exit 1
fi

TEMPLATE="files/traefik/dynamic.tmpl.yml"
OUTPUT="files/traefik/dynamic.yml"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Template not found: $TEMPLATE" >&2
  exit 1
fi

# Load .env if present to populate variables
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

# Defaults
export DOMAIN="${DOMAIN:-localhost}"
export GRAFANA_DOMAIN="${GRAFANA_DOMAIN:-}"
export GRAFANA_PATH="${GRAFANA_PATH:-/grafana}"
export TRAEFIK_PROTOCOL="${TRAEFIK_PROTOCOL:-http}"

mkdir -p "$(dirname "$OUTPUT")"
envsubst < "$TEMPLATE" > "$OUTPUT"

echo "Rendered Traefik dynamic config to $OUTPUT"