# MSPR Infra — Local Development

Docker Compose stack for the MSPR platform. All HTTP traffic enters through an NGINX gateway on port 8080.

Full documentation: [`docs/`](docs/)

---

## Quick Start

```bash
cp .env.example .env
# Set MSPR_*_SOURCE_DIR values to your local service checkouts, then:
./scripts/up.sh
```

→ See [Getting Started](docs/01-getting-started.md) for the full setup walkthrough.

---

## Gateway Routes

| Path          | Service                 |
| ------------- | ----------------------- |
| `/auth/*`     | Keycloak                |
| `/api/*`      | healthbook-api          |
| `/tracking/*` | tracking-api            |
| `/data/*`     | data-recommendation-api |
| `/brain/*`    | healthai-brain-nest-api |

NGINX strips the prefix before forwarding. JWT validation is handled by each service, not the gateway.

The Brain FastAPI (`healthai-brain-fastapi-api`) is internal — not exposed through the gateway, only reachable from `healthai-brain-nest-api` on the Docker network.

→ See [URL Cheat Sheet](docs/00-url-cheat-sheet.md) for all internal and external URLs.

---

## Profiles

| Profile      | Containers                                                                                                 |
| ------------ | ---------------------------------------------------------------------------------------------------------- |
| `core`       | nginx, keycloak, postgres_keycloak                                                                         |
| `services`   | healthbook-api, tracking-api, data-recommendation-api, healthai-brain-nest-api, healthai-brain-fastapi-api |
| `data`       | postgres_api, postgres_tracking, postgres_data, postgres_brain                                             |
| `monitoring` | prometheus, loki, grafana, promtail                                                                        |
| `airflow`    | airflow-webserver, airflow-scheduler, airflow-init, postgres_airflow                                       |
| `deep-data`  | clickhouse, minio                                                                                          |

→ See [How It Works](docs/02-how-it-works.md) for architecture details.

---

## Scripts

| Script                                   | What it does                                                |
| ---------------------------------------- | ----------------------------------------------------------- |
| `./scripts/up.sh [profiles…]`            | Start all profiles (or a subset)                            |
| `./scripts/down.sh`                      | Stop all containers                                         |
| `./scripts/logs.sh [service…]`           | Tail logs (all or per-service)                              |
| `./scripts/dev.sh [service…]`            | Hot-reload mode — bind-mounts source and runs watch command |
| `./scripts/npm-install.sh [service…]`    | Run `npm install` inside a running NestJS container         |
| `./scripts/sync-bruno.sh`                | Regenerate Bruno collection from live OpenAPI specs         |
| `./scripts/reset.sh --yes`               | Full teardown — remove all containers and named volumes     |
| `./scripts/reset.sh --yes <service> […]` | Per-service reset — remove container and its volumes only   |

→ See [Operations Guide](docs/03-operations-guide.md) for usage details and environment variable reference.

---

## Key Notes

- Source paths are configured via `MSPR_*_SOURCE_DIR` in `.env`.
- First start of `healthai-brain-fastapi-api` installs PyTorch — can take several minutes. Subsequent starts are instant (venv persisted in `brain_venv` volume).
- This stack is for local development only — no TLS, no HA, no production hardening.

→ See [Troubleshooting](docs/04-troubleshooting.md) for common issues and fixes.

## Machine learning

- uv run jupyter nbconvert --to notebook --execute --inplace 05_serialisation.ipynb
