# Getting Started

## Purpose of This Repository

This repository boots the local MSPR platform stack with Docker Compose.
The gateway entrypoint is NGINX on port 8080 by default.

Main paths:

- /auth/\* -> Keycloak
- /api/\* -> MSPR API service
- /tracking/\* -> MSPR Tracking service
- /data/\* -> MSPR Data service

Important: NGINX does not validate JWTs. Each service must validate Keycloak tokens.

## Prerequisites

- Docker Engine or Docker Desktop with Docker Compose plugin
- Network access to pull images
- GHCR credentials if service images are private

## Initial Setup

1. Copy environment template:

```bash
cp .env.example .env
```

2. Update required values in .env:

- ORG_NAME
- MSPR_API_IMAGE
- MSPR_TRACKING_IMAGE
- MSPR_DATA_IMAGE
- MSPR_API_SOURCE_DIR, MSPR_TRACKING_SOURCE_DIR, MSPR_DATA_SOURCE_DIR if you want hot reload from local checkouts
- Optional password and port overrides

3. If images are private, login to GHCR:

```bash
docker login ghcr.io
```

## Start Commands

### Full stack

```bash
./scripts/up.sh
```

By default this starts profiles:

- core
- services
- data
- monitoring
- airflow

### Hot reload one or more services

When you have the service source code locally, start infra and run selected services in dev mode:

```bash
./scripts/dev.sh mspr_api
```

You can pass multiple services:

```bash
./scripts/dev.sh mspr_api mspr_tracking
```

This uses bind mounts from `MSPR_*_SOURCE_DIR` and runs the service watch command from `MSPR_*_DEV_COMMAND`.

If you also want non-selected services to run from image tags:

```bash
./scripts/dev.sh --with-images mspr_api
```

### Minimal app stack

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

### Stop stack

```bash
./scripts/down.sh
```

Use the same stop command for dev mode.

### Follow logs

```bash
./scripts/logs.sh
```

## First Health Checks

Gateway health:

```bash
curl -i http://localhost:8080/health
```

Expected: HTTP 200 and body "ok".

Keycloak through gateway:

```bash
curl -i http://localhost:8080/auth/
```

Expected: redirect or login page response once Keycloak is fully started.

## Service Endpoints

- Gateway: http://localhost:${GATEWAY_PORT:-8080}
- Keycloak via gateway: http://localhost:${GATEWAY_PORT:-8080}/auth/
- Airflow: http://localhost:${AIRFLOW_PORT:-8081}
- Grafana: http://localhost:${GRAFANA_PORT:-3001}
- Prometheus: http://localhost:${PROMETHEUS_PORT:-9090}
- Loki: http://localhost:${LOKI_PORT:-3100}

## Notes About Startup Ordering

Compose depends_on controls start order, not service readiness.
Application services should implement retry logic for databases and auth endpoints.
