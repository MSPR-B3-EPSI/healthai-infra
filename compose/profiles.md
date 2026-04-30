# Compose Profiles

All commands below use this file set:

```bash
docker compose \
  -f compose/compose.core.yaml \
  -f compose/compose.services.yaml \
  -f compose/compose.data.yaml \
  -f compose/compose.airflow.yaml \
  -f compose/compose.monitoring.yaml
```

## Core only

```bash
docker compose -f compose/compose.core.yaml --profile core up -d
```

## App services (gateway + auth + services + DBs)

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

## Monitoring only

```bash
docker compose \
  -f compose/compose.monitoring.yaml \
  --profile monitoring \
  up -d
```

## Airflow only

```bash
docker compose \
  -f compose/compose.airflow.yaml \
  --profile airflow \
  up -d
```

## Full stack

```bash
./scripts/up.sh
```

## Full stack plus hot reload

```bash
./scripts/dev.sh healthbook-api
```

This starts infra profiles (core, data, monitoring, airflow), then starts selected services with local source mounts and watch mode.
