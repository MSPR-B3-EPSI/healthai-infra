# Operations Guide

## Compose File Composition

Most commands should include all compose files:

```bash
docker compose \
  -f compose/compose.core.yaml \
  -f compose/compose.services.yaml \
  -f compose/compose.data.yaml \
  -f compose/compose.airflow.yaml \
  -f compose/compose.monitoring.yaml
```

## Profiles and Use Cases

### core

Use when validating gateway and identity only.

```bash
docker compose -f compose/compose.core.yaml --profile core up -d
```

### services + data + core

Use for API integration and auth flow tests.

```bash
docker compose \
  -f compose/compose.core.yaml \
  -f compose/compose.services.yaml \
  -f compose/compose.data.yaml \
  --profile core --profile services --profile data up -d
```

### monitoring

Use when validating observability stack only.

This profile runs Prometheus, Loki, Grafana, and Promtail.

Provisioned dashboards include:

- MSPR Overview
- MSPR Container Logs

```bash
docker compose -f compose/compose.monitoring.yaml --profile monitoring up -d
```

### airflow

Use when validating schedule workloads.

```bash
docker compose -f compose/compose.airflow.yaml --profile airflow up -d
```

## Repository Helper Scripts

Start all profiles:

```bash
./scripts/up.sh
```

Start specific profiles only:

```bash
./scripts/up.sh core services data
```

Stop containers:

```bash
./scripts/down.sh
```

Tail logs:

```bash
./scripts/logs.sh
```

Tail logs for one service:

```bash
./scripts/logs.sh nginx
```

Reset stack and delete all named volumes (destructive):

```bash
./scripts/reset.sh --yes
```

## Environment Variable Reference

### Image and namespace

- ORG_NAME
- MSPR_API_IMAGE
- MSPR_TRACKING_IMAGE
- MSPR_DATA_IMAGE

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
2. Verify .env still has correct image tags.
3. Start required profiles only.
4. Validate gateway /health and /auth.
5. Run feature-specific tests.
6. Stop stack when finished.

## Security Notes for Local Development

- Credentials in .env.example are development defaults.
- Never commit real secrets to git.
- Replace default passwords in shared environments.

## Updating Service Images

Change tag values in .env:

- MSPR_API_IMAGE
- MSPR_TRACKING_IMAGE
- MSPR_DATA_IMAGE

Then recreate affected containers:

```bash
docker compose \
  -f compose/compose.core.yaml \
  -f compose/compose.services.yaml \
  -f compose/compose.data.yaml \
  --profile core --profile services --profile data up -d --force-recreate
```
