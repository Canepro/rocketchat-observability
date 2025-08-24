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

# Remove invalid grafana-subdomain router if GRAFANA_DOMAIN is empty
if [[ -z "${GRAFANA_DOMAIN:-}" ]]; then
	echo "GRAFANA_DOMAIN is empty, removing grafana-subdomain router from config"
	# Remove the entire grafana-subdomain router block including comments and config
	sed -i '/# Note: grafana-subdomain router requires GRAFANA_DOMAIN/,/middlewares: \[\]/d' "$OUTPUT"
fi

# Add HTTPS routers if TRAEFIK_PROTOCOL is https
if [[ "${TRAEFIK_PROTOCOL}" == "https" ]]; then
	echo "Adding HTTPS routers with TLS configuration"
	
	# Add HTTPS rocketchat router
	cat >> "$OUTPUT" << EOF

    rocketchat-https:
      rule: "Host(\`${DOMAIN}\`)"
      entryPoints:
        - websecure
      service: rocketchat-svc
      middlewares: []
      tls:
        certResolver: le

    grafana-path-https:
      rule: "Host(\`${DOMAIN}\`) && PathPrefix(\`${GRAFANA_PATH}\`)"
      entryPoints:
        - websecure
      service: grafana-svc
      middlewares:
        - grafana-strip
      tls:
        certResolver: le
EOF

	# Add HTTPS grafana-subdomain router if GRAFANA_DOMAIN is set
	if [[ -n "${GRAFANA_DOMAIN:-}" ]]; then
		cat >> "$OUTPUT" << EOF

    grafana-subdomain-https:
      rule: "Host(\`${GRAFANA_DOMAIN}\`)"
      entryPoints:
        - websecure
      service: grafana-svc
      middlewares: []
      tls:
        certResolver: le
EOF
	fi
fi

echo "Rendered Traefik dynamic config to $OUTPUT"