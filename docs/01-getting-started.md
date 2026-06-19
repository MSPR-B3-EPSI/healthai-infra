# Getting Started

## Purpose of This Repository

This repository boots the local MSPR platform stack with Docker Compose.
The gateway entrypoint is NGINX on port 8080 by default.

Main paths:

- /auth/\* -> Keycloak
- /api/\* -> HealthBook API service
- /tracking/\* -> Tracking API service
- /data/\* -> Data Recommendation API service
- /brain/\* -> Brain NestJS API service

Important: NGINX does not validate JWTs. Each service must validate Keycloak tokens.
The Brain FastAPI (AI inference) is internal only — not exposed through the gateway.

## Prerequisites

- Docker Engine or Docker Desktop with Docker Compose plugin
- Network access to pull base images (Keycloak, Postgres, Node)

## Initial Setup

1. Copy environment template:

```bash
cp .env.example .env
```

2. Update required values in .env:

- MSPR_API_SOURCE_DIR, MSPR_TRACKING_SOURCE_DIR, MSPR_DATA_SOURCE_DIR (local service checkouts)
- MSPR_BRAIN_NEST_SOURCE_DIR (path to healthai-brain-api/exposed-nest-api)
- MSPR_BRAIN_FASTAPI_SOURCE_DIR (path to healthai-brain-api/hidden-fastapi)
- Optional password and port overrides

Note: on first start, the Brain FastAPI container installs Python dependencies including PyTorch.
This can take several minutes. Subsequent starts are instant because the venv is persisted in the
`brain_venv` Docker volume.

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

You can start the whole infrastructure with all the apis in watch mode just by launching the dev script

```bash
./scripts/dev.sh healthbook-api
```

When you have the service source code locally, start infra and run selected services in dev mode:

```bash
./scripts/dev.sh healthbook-api
```

You can pass multiple services:

```bash
./scripts/dev.sh healthbook-api tracking-api
```

Brain API services:

```bash
./scripts/dev.sh healthai-brain-nest-api healthai-brain-fastapi-api
```

This uses bind mounts from `MSPR_*_SOURCE_DIR` and runs the service watch command from `MSPR_*_DEV_COMMAND`.

### Minimal app stack

```bash
./scripts/up.sh core services data
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
