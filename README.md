
# Rocket.Chat Observability Stack

> **⚠️ WARNING: This stack is for LOCAL TESTING and LAB USE ONLY.**
>
> - **Do NOT use in production.**
> - No TLS, no database auth, and default passwords are used.
> - Exposed services may be insecure if run outside localhost.

![Compose Lint](https://github.com/Canepro/rocketchat-observability/actions/workflows/compose-lint.yml/badge.svg?branch=main)


A reference **Podman/Docker Compose stack** for local testing and observability of Rocket.Chat, with:


## Services Overview

- **Rocket.Chat**: The main chat application.
- **MongoDB**: Database backend for Rocket.Chat.
- **MongoDB Exporter**: Exposes MongoDB metrics for Prometheus.
- **NATS**: Message broker for Rocket.Chat clustering.
- **NATS Exporter**: Exposes NATS metrics for Prometheus.
- **Traefik**: Reverse proxy and router for HTTP(S) traffic.
- **Prometheus**: Collects and stores metrics from all exporters.
- **Grafana**: Visualizes metrics and dashboards.
- **Node Exporter**: Exposes host system metrics for Prometheus.

---

## Architecture


```text
[Client] -> [Traefik :80/:443] -> [Rocket.Chat :3000]
                          ├─> [Grafana :/grafana or :5050]
                          └─> [Prometheus :9000]
[MongoDB] <-> [MongoDB Exporter :9216]
[NATS] -> [NATS Exporter :7777]
[Host] -> [Node Exporter :9100]
```

---


---

## Quickstart

```bash
# Clone repo and prepare environment
cp .env.example .env
# Edit .env if needed (domains, ports, passwords)

# Start the stack (preferred: Makefile wrapper)
make up
# or (direct):
podman-compose up -d
# or:
docker compose up -d
```

> **Never commit your real `.env` file to version control!**


### Access the services

- **Rocket.Chat** → [http://localhost:3000](http://localhost:3000)
- **Grafana** → [http://grafana.localhost/grafana](http://grafana.localhost/grafana)
  - Default login: `admin` / password from `.env` (`GRAFANA_ADMIN_PASSWORD`)
- **Prometheus** → [http://127.0.0.1:9000](http://127.0.0.1:9000) (bound to localhost)
- **Traefik Dashboard** → [http://localhost:8080](http://localhost:8080) (if `TRAEFIK_API_INSECURE=true`)

### Shutdown & reset



```bash
podman-compose down -v  # stops stack and wipes volumes
```

---


---

## Troubleshooting

- **Port already in use**: Make sure no other service is using the same port, or change the port in `.env`.
- **Images not found**: Run `docker compose pull` or `podman compose pull` to fetch images.
- **Permission denied on volumes**: Ensure your user has permission to write to the volume directories.
- **Services not starting**: Check logs with `make logs` or `docker compose logs` for errors.

---

## Security Notes

- Example config is for **local lab/testing only**.
- Traefik is configured **without TLS** (`http://` only).
- MongoDB runs **without authentication** by default (simplifies testing).
- Prometheus is bound to **127.0.0.1** for safety.
- Always change default passwords in `.env`.

---

## License

MIT
