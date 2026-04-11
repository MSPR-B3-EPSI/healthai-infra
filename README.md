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
- Access to GHCR images if your service images are private

## Quick Start

1. Copy environment variables:

```bash
cp .env.example .env
```

2. If your images are private, log in to GHCR:

```bash
docker login ghcr.io
```

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
./scripts/dev.sh mspr_api
```

This starts core infra profiles first (gateway, auth, data, monitoring, airflow), then runs only the selected services in bind-mounted watch mode.

If you also want non-selected services to stay image-based:

```bash
./scripts/dev.sh --with-images mspr_api
```

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
- `compose/compose.services.yaml`: `mspr_api`, `mspr_tracking`, `mspr_data`
- `compose/compose.data.yaml`: service Postgres DBs and optional MinIO
- `compose/compose.airflow.yaml`: Airflow and Airflow Postgres
- `compose/compose.monitoring.yaml`: Prometheus, Loki, Grafana, Promtail

See `compose/profiles.md` for profile-only startup examples.

## Important Notes

- Service images are placeholders by default. Set valid values for:
  - `MSPR_API_IMAGE`
  - `MSPR_TRACKING_IMAGE`
  - `MSPR_DATA_IMAGE`
- Services should implement retry logic for DB startup races.
- NGINX strips service prefixes (`/api`, `/tracking`, `/data`) before proxying.
- Update image tags in `.env` to switch service versions quickly.
- This setup is for local development only (no TLS, no HA, no production hardening).

## Utility Scripts

- `./scripts/up.sh` starts all profiles by default
- `./scripts/dev.sh [--with-images] [mspr_api] [mspr_tracking] [mspr_data]` starts infra, then runs selected services in hot reload mode
- `./scripts/down.sh` stops containers
- `./scripts/logs.sh` tails logs
- `./scripts/reset.sh --yes` stops stack and removes volumes
