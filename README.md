# Rocket.Chat Observability Stack

![Compose Lint](https://github.com/Canepro/rocketchat-observability/actions/workflows/compose-lint.yml/badge.svg?branch=main)

A reference **Podman/Docker Compose stack** for local testing and observability of Rocket.Chat, with:

* **Rocket.Chat**
* **MongoDB** + MongoDB Exporter
* **NATS** (transporter)
* **Traefik** (reverse proxy / router)
* **Prometheus** (metrics collection)
* **Grafana** (dashboards)
* **Node Exporter** (host metrics)

---

## Architecture

```
[Client] -> [Traefik :80/:443] -> [Rocket.Chat :3000]
                           ├─> [Grafana :/grafana or :5050]
                           └─> [Prometheus :9000]
[MongoDB] <-> [MongoDB Exporter :9216]
[NATS] -> [NATS Exporter :7777]
[Host] -> [Node Exporter :9100]
```

---

## Quickstart

```bash
# Clone repo and prepare environment
cp .env.example .env
# Edit .env if needed (domains, ports, passwords)

# Start stack
podman-compose up -d
# or: docker compose up -d
```

### Access the services

* **Rocket.Chat** → [http://localhost:3000](http://localhost:3000)
* **Grafana** → [http://grafana.localhost/grafana](http://grafana.localhost/grafana)

  * Default login: `admin` / password from `.env` (`GRAFANA_ADMIN_PASSWORD`)
* **Prometheus** → [http://127.0.0.1:9000](http://127.0.0.1:9000) (bound to localhost)
* **Traefik Dashboard** → [http://localhost:8080](http://localhost:8080) (if `TRAEFIK_API_INSECURE=true`)

### Shutdown & reset

```bash
podman-compose down -v  # stops stack and wipes volumes
```

---

## Security Notes

* Example config is for **local lab/testing only**.
* Traefik is configured **without TLS** (`http://` only).
* MongoDB runs **without authentication** by default (simplifies testing).
* Prometheus is bound to **127.0.0.1** for safety.
* Always change default passwords in `.env`.

---

## License

MIT
