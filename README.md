# MSPR Infra (Local Development)

This repository runs the MSPR local platform with Docker Compose.

Detailed documentation is available in `docs/README.md`.

Gateway entry point: http://localhost:8080

Routing is handled by NGINX:

- `/auth/*` -> Keycloak
- `/api/*` -> HealthBook API service
- `/tracking/*` -> Tracking API service
- `/data/*` -> Public/static data API service

NGINX does not validate auth tokens. Each Nest service must validate Keycloak JWTs.

## Prerequisites

- Docker Engine or Docker Desktop with Compose plugin

## Quick Start

1. Copy environment variables:

```bash
cp .env.example .env
```

2. Ensure local service source checkouts exist (defaults are sibling folders):

- `MSPR_API_SOURCE_DIR=../healthbook-api`
- `MSPR_TRACKING_SOURCE_DIR=../tracking-api`
- `MSPR_DATA_SOURCE_DIR=../data-recommendation-api`

Update `.env` if your paths differ.

3. Start a minimal stack (gateway + keycloak + databases + services):

```bash
docker compose \
  -f compose/compose.core.yaml \
  -f compose/compose.services.yaml \
  -f compose/compose.data.yaml \
  --profile core \
  --profile services \
  --profile data \
  up -d
```

4. Start the full stack (including Airflow + monitoring):

```bash
./scripts/up.sh
```

5. Start one or more services in hot-reload mode when you have local source checkouts:

```bash
./scripts/dev.sh healthbook-api
```

This starts core infra profiles first (gateway, auth, data, monitoring, airflow), then runs only the selected services in bind-mounted watch mode.

## URLs

- Gateway: http://localhost:${GATEWAY_PORT:-8080}
- Gateway health: http://localhost:${GATEWAY_PORT:-8080}/health
- Keycloak via gateway: http://localhost:${GATEWAY_PORT:-8080}/auth/
- Airflow: http://localhost:${AIRFLOW_PORT:-8081}
- Grafana: http://localhost:${GRAFANA_PORT:-3001}
- Prometheus: http://localhost:${PROMETHEUS_PORT:-9090}
- Loki: http://localhost:${LOKI_PORT:-3100}

## Compose Files

- `compose/compose.core.yaml`: NGINX, Keycloak, Keycloak Postgres
- `compose/compose.services.yaml`: `healthbook-api`, `tracking-api`, `data-recommendation-api` (bind mount + watch mode)
- `compose/compose.data.yaml`: service Postgres DBs and optional MinIO
- `compose/compose.airflow.yaml`: Airflow and Airflow Postgres
- `compose/compose.monitoring.yaml`: Prometheus, Loki, Grafana, Promtail

See `compose/profiles.md` for profile-only startup examples.

## Important Notes

- Service containers bind mount local source paths from `MSPR_*_SOURCE_DIR`.
- Update `MSPR_*_DEV_COMMAND` in `.env` if you need a different dev command.
- Services should implement retry logic for DB startup races.
- NGINX strips service prefixes (`/api`, `/tracking`, `/data`) before proxying.
- This setup is for local development only (no TLS, no HA, no production hardening).

## Utility Scripts

- `./scripts/up.sh` starts all profiles by default
- `./scripts/dev.sh [healthbook-api] [tracking-api] [data-recommendation-api]` starts infra, then runs selected services in hot reload mode
- `./scripts/down.sh` stops containers
- `./scripts/logs.sh` tails logs
- `./scripts/reset.sh --yes` stops stack and removes volumes
