# How It Works

## High-Level Architecture

The stack is organized into compose profile groups:

- core
  - nginx
  - keycloak
  - postgres_keycloak
- services
  - mspr_api
  - mspr_tracking
  - mspr_data
- data
  - postgres_api
  - postgres_tracking
  - postgres_data
  - minio (optional dev data lake)
- airflow
  - postgres_airflow
  - airflow-init
  - airflow-webserver
  - airflow-scheduler
- monitoring
  - prometheus
  - loki
  - grafana
  - promtail

All services share one Docker network named app in each compose file.

## Reverse Proxy Design

NGINX is the single entrypoint for HTTP traffic.

Routing rules:

- /auth/ -> keycloak:8080/
- /api/ -> mspr_api:3000
- /tracking/ -> mspr_tracking:3000
- /data/ -> mspr_data:3000

Path prefixes are stripped before forwarding to backend services.
Example: /api/v1/patients is forwarded as /v1/patients.

Gateway health endpoint:

- /health returns 200 from NGINX directly.

## Auth Responsibility Boundary

- NGINX does not perform JWT validation.
- Each Nest service validates Bearer tokens itself.

Service auth variables:

- KEYCLOAK_ISSUER should match JWT iss claim.
- KEYCLOAK_AUDIENCE should match JWT aud claim for each service.

In this repository, issuer is typically:

- http://keycloak:8080/realms/mspr

## Data Layer Model

Each API service has an isolated Postgres database:

- mspr_api -> postgres_api
- mspr_tracking -> postgres_tracking
- mspr_data -> postgres_data

Additional databases:

- postgres_keycloak for Keycloak metadata
- postgres_airflow for Airflow metadata

Optional storage:

- MinIO can be used as local object storage (data lake style) in dev.

## Monitoring Model

Prometheus:

- Scrapes itself
- Contains placeholders for service metrics on /metrics

Loki:

- Runs in single binary mode
- Stores data in local filesystem within container volume paths

Promtail:

- Discovers Docker containers for this stack via Docker service discovery
- Tails container JSON logs and pushes them to Loki
- Labels logs with compose project and compose service for filtering in Grafana
- Excludes monitoring self-logs (loki, promtail, grafana, prometheus) to avoid recursive log amplification

Grafana:

- Starts with pre-provisioned datasources
  - Prometheus at http://prometheus:9090
  - Loki at http://loki:3100
- Loads dashboards from monitoring/grafana/dashboards

## Airflow Model

Airflow profile includes:

- DB initialization and migration via airflow-init
- Webserver for UI access
- Scheduler for DAG execution
- Local mounts for dags, plugins, and requirements

DAGs represent scheduled jobs (archival, backup, restore, ETL, etc.).

## Why Service Ports Are Not Published

Service containers use expose: 3000 and are not bound to host ports.
This enforces gateway-first access patterns and keeps host port usage clean.

## Keycloak Access Paths

Internal (from containers):

- http://keycloak:8080/realms/mspr

External (through gateway):

- http://localhost:8080/auth/

Keep issuer usage consistent between token issuing and token validation paths.
