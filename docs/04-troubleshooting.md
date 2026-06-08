# Troubleshooting

## 1) NGINX is running but /auth returns 502

Possible causes:

- Keycloak still booting
- Keycloak failed startup due to DB/auth settings

Checks:

```bash
./scripts/logs.sh keycloak
```

Fix:

- Wait until Keycloak log reports it is listening on 0.0.0.0:8080.
- Verify KC*POSTGRES*\* values.

## 2) /health works but /api returns 502

Possible causes:

- services profile is not running
- service container crash

Checks:

```bash
./scripts/logs.sh healthbook-api
./scripts/logs.sh tracking-api
./scripts/logs.sh data-recommendation-api
```

Fix:

- Start missing profiles: `./scripts/up.sh core services data`
- Check logs for the failing service.

## 3) Services fail at startup with DB connection errors

Cause:

- DB containers started but not yet ready.

Fix:

- Implement retry/backoff in each service startup.
- Restart service container once DB is healthy.

## 4) JWT validation fails with issuer mismatch

Symptoms:

- 401 responses with invalid issuer details.

Fix:

- Ensure KEYCLOAK_ISSUER in services matches the token iss claim exactly.
- Standardize whether your clients issue/use internal or external Keycloak URL.

Common local value:

- http://keycloak:8080/realms/mspr

## 5) JWT validation fails with audience mismatch

Symptoms:

- 401 responses where token aud does not match expected service audience.

Fix:

- Confirm KEYCLOAK_AUDIENCE_API, KEYCLOAK_AUDIENCE_TRACKING, KEYCLOAK_AUDIENCE_DATA, KEYCLOAK_AUDIENCE_BRAIN values.
- Confirm Keycloak client scopes and audience mapper configuration.

## 6) Grafana starts but dashboards or datasources are missing

Checks:

```bash
./scripts/logs.sh grafana
```

Fix:

- Verify mounted files exist:
  - monitoring/grafana/provisioning/datasources/datasources.yaml
  - monitoring/grafana/provisioning/dashboards/dashboards.yaml
  - monitoring/grafana/dashboards/mspr-overview.json
  - monitoring/grafana/dashboards/mspr-container-logs.json
- Restart monitoring profile.

## 7) Prometheus targets are down

Checks:

- Ensure services expose /metrics endpoint.
- Validate target names in monitoring/prometheus/prometheus.yml.

Note:

- Placeholder targets are configured. Services must actually implement metrics endpoints.

## 8) Loki datasource is up but no logs are visible

Checks:

```bash
./scripts/logs.sh promtail loki
```

Fix:

- Verify monitoring/promtail/promtail-config.yaml exists and is mounted.
- Verify Docker socket mount is available in promtail.
- Verify /var/lib/docker/containers is mounted read-only in promtail.
- Confirm services are running in the expected profiles so promtail can discover them.

## 9) Airflow webserver/scheduler loops or exits

Checks:

```bash
./scripts/logs.sh airflow-init airflow-webserver airflow-scheduler
```

Fix:

- Verify AIRFLOW*POSTGRES*\* values.
- Confirm airflow-init completed db migration and admin creation.
- Confirm airflow/requirements.txt is valid.

## 10) Need a clean state

**Full stack reset** — removes all containers and named volumes:

```bash
./scripts/reset.sh --yes
```

**Single service reset** — removes the container and its named volumes:

```bash
./scripts/reset.sh --yes <service-name>
./scripts/up.sh <profiles>
```

Run `./scripts/reset.sh` without arguments to see the service → volume reference.

## 11) /brain returns 502

Possible causes:

- healthai-brain-nest-api not started or still booting
- healthai-brain-fastapi-api not ready yet (first start installs PyTorch, takes several minutes)

Checks:

```bash
./scripts/logs.sh healthai-brain-nest-api healthai-brain-fastapi-api
```

Fix:

- Wait for the FastAPI log line: `Application startup complete.`
- On very first start, pip install of PyTorch can take 5-15 minutes depending on network speed.
- If pip install fails, delete the `brain_venv` volume and restart: `docker volume rm healthai_brain_venv`

## 12) Brain FastAPI is slow to start

Cause:

- First startup creates a Python venv and installs requirements including PyTorch (~2GB default, ~200MB CPU-only).

Fix:

- Wait for the log line `Application startup complete.` in healthai-brain-fastapi-api.
- Subsequent restarts are instant because the venv is persisted in the `brain_venv` Docker volume.
- To use the CPU-only PyTorch wheel (recommended for dev), update requirements.txt in hidden-fastapi:

```
--extra-index-url https://download.pytorch.org/whl/cpu
torch==2.2.1
```

## 13) Compose command shows no services

Cause:

- No active profile selected.

Fix:

- Use --profile flags explicitly, or use scripts/up.sh defaults.
