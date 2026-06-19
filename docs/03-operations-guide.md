# Operations Guide

## Repository Helper Scripts

All scripts live in `scripts/` and handle compose file selection automatically.
Run them from the repo root or any subdirectory — they resolve paths from their own location.

### up.sh — start profiles

Start all profiles (default):

```bash
./scripts/up.sh
```

Start specific profiles only:

```bash
./scripts/up.sh core services data
```

Available profiles: `core`, `services`, `data`, `monitoring`, `airflow`, `deep-data`

### down.sh — stop containers

```bash
./scripts/down.sh
```

### logs.sh — tail logs

(note that running the monitoring service easily replace and outperform this utility script )

Tail all running services:

```bash
./scripts/logs.sh
```

Tail a specific service or multiple services:

```bash
./scripts/logs.sh nginx
./scripts/logs.sh healthai-brain-nest-api healthai-brain-fastapi-api
```

### dev.sh — hot-reload mode

Starts infra profiles then mounts source code and runs the watch command for each selected service.
Requires `MSPR_*_SOURCE_DIR` env vars to point at the service checkouts.

```bash
./scripts/dev.sh healthbook-api
./scripts/dev.sh healthbook-api tracking-api data-recommendation-api
./scripts/dev.sh healthai-brain-nest-api healthai-brain-fastapi-api
```

### npm-install.sh — install Node dependencies inside a running container

Run `npm install` inside a running NestJS service container (useful after adding a package):

```bash
./scripts/npm-install.sh
./scripts/npm-install.sh healthbook-api
```

### sync-bruno.sh — regenerate Bruno collection from live OpenAPI specs

Fetches the `/api-json` spec from each running service and writes `.bru` request files into `bruno/`:

```bash
./scripts/sync-bruno.sh
```

Services must be running before calling this. Existing request files are replaced.

### reset.sh — teardown with volume clearing (destructive)

Full stack reset — removes all containers and all named volumes:

```bash
./scripts/reset.sh --yes
```

Per-service reset — removes the container and only its named volumes:

```bash
./scripts/reset.sh --yes <service> [service...]
```

Run without `--yes` to see usage and the service → volume reference.

#### Examples

Wipe the brain NestJS database only:

```bash
./scripts/reset.sh --yes postgres_brain
./scripts/up.sh data
```

Force-reinstall the Brain FastAPI Python venv (e.g. after changing `requirements.txt`):

```bash
./scripts/reset.sh --yes healthai-brain-fastapi-api
./scripts/up.sh services
```

Re-download HuggingFace model weights only (keeps the venv):

```bash
./scripts/reset.sh --yes healthai-brain-fastapi-api
# Then manually: docker volume rm healthai_brain_hf_cache  (brain_venv stays)
./scripts/up.sh services
```

Reset Keycloak and its database (realm import re-applies on restart):

```bash
./scripts/reset.sh --yes keycloak postgres_keycloak
./scripts/up.sh core
```

## Adding a Dependency to a Service

### NestJS services (healthbook-api, tracking-api, data-recommendation-api, healthai-brain-nest-api)

1. Add the package to `package.json` in the service source repo.
2. Install it inside the running container:

```bash
./scripts/npm-install.sh <service-name>
```

The watch process will reload automatically after install. If the service is not running, start it first with `./scripts/dev.sh <service-name>`.

### Brain FastAPI (healthai-brain-fastapi-api)

1. Add the package to `hidden-fastapi/requirements.txt`.
2. Delete the `brain_venv` volume so the startup script reinstalls:

```bash
./scripts/reset.sh --yes healthai-brain-fastapi-api
./scripts/up.sh services
```

The container installs the full venv on its next start and then launches uvicorn.

## Profiles and Use Cases

### core

Gateway and Keycloak only. Use when validating identity flows.

```bash
./scripts/up.sh core
```

### services + data + core

API integration and auth flow tests.

```bash
./scripts/up.sh core services data
```

### monitoring

Prometheus, Loki, Grafana, and Promtail.

Provisioned dashboards include:

- MSPR Overview
- MSPR Container Logs

```bash
./scripts/up.sh monitoring
```

### airflow

Scheduled workload validation.

```bash
./scripts/up.sh airflow
```

## Environment Variable Reference

### Public ports

- GATEWAY_PORT
- AIRFLOW_PORT
- GRAFANA_PORT
- PROMETHEUS_PORT
- LOKI_PORT
- MINIO_PORT
- MINIO_CONSOLE_PORT

### Keycloak

- KEYCLOAK_REALM
- KEYCLOAK_ISSUER_INTERNAL
- KEYCLOAK_ADMIN
- KEYCLOAK_ADMIN_PASSWORD
- KC_POSTGRES_DB
- KC_POSTGRES_USER
- KC_POSTGRES_PASSWORD

### Service audiences

- KEYCLOAK_AUDIENCE_API
- KEYCLOAK_AUDIENCE_TRACKING
- KEYCLOAK_AUDIENCE_DATA
- KEYCLOAK_AUDIENCE_BRAIN

### API DB settings

- API_POSTGRES_DB
- API_POSTGRES_USER
- API_POSTGRES_PASSWORD
- API_DATABASE_URL

### Tracking DB settings

- TRACKING_POSTGRES_DB
- TRACKING_POSTGRES_USER
- TRACKING_POSTGRES_PASSWORD
- TRACKING_DATABASE_URL

### Data DB settings

- DATA_POSTGRES_DB
- DATA_POSTGRES_USER
- DATA_POSTGRES_PASSWORD
- DATA_DATABASE_URL

### Brain DB settings

- BRAIN_POSTGRES_DB
- BRAIN_POSTGRES_USER
- BRAIN_POSTGRES_PASSWORD
- BRAIN_DATABASE_URL

### Brain source and dev commands

- MSPR_BRAIN_NEST_SOURCE_DIR (path to exposed-nest-api checkout)
- MSPR_BRAIN_FASTAPI_SOURCE_DIR (path to hidden-fastapi checkout)
- MSPR_BRAIN_DEV_COMMAND (NestJS watch command override)
- MSPR_BRAIN_FASTAPI_DEV_COMMAND (uvicorn startup command override)
- BRAIN_AI_SERVICE_URL (FastAPI internal URL seen by nest, default: http://healthai-brain-fastapi-api:8000)

### Airflow DB settings

- AIRFLOW_POSTGRES_DB
- AIRFLOW_POSTGRES_USER
- AIRFLOW_POSTGRES_PASSWORD
- AIRFLOW_ADMIN_USER
- AIRFLOW_ADMIN_PASSWORD

### Optional MinIO settings

- MINIO_ROOT_USER
- MINIO_ROOT_PASSWORD

## Recommended Daily Workflow

1. Pull latest repository changes.
2. Verify .env has correct source paths and dev commands.
3. Start required profiles only.
4. Validate gateway /health and /auth.
5. Run feature-specific tests.
6. Stop stack when finished.

## Security Notes for Local Development

- Credentials in .env.example are development defaults.
- Never commit real secrets to git.
- Replace default passwords in shared environments.
