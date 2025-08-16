# Rocket.Chat Observability Stack

![Compose Lint](https://github.com/Canepro/rocketchat-observability/actions/workflows/compose-lint.yml/badge.svg?branch=main)

A reference docker-compose stack: Rocket.Chat + MongoDB + Prometheus + Grafana + Traefik + exporters.

## Architecture

`
[Client] -> [Traefik :80] -> [Rocket.Chat 3000]
                         \-> [Prometheus 9090]
                         \-> [Grafana 3001]
[MongoDB] <-> [MongoDB Exporter]
[Host] -> [Node Exporter]
`

## Quickstart
`pwsh
cp .env.example .env
# Optionally adjust image tags/ports

docker compose up -d
# Access Rocket.Chat: http://localhost:3000
# Prometheus: http://localhost:9090
# Grafana: http://localhost:3001 (admin/admin by default)
# Traefik: http://localhost:8081

docker compose down -v  # to reset volumes
`

## Security Notes
- Example credentials only; change in .env.
- No TLS; behind Traefik :80 for local lab use only.
- Mongo runs without authentication for simplicity; use auth in production.

## License
MIT