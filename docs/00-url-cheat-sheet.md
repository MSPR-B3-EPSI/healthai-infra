# URL Cheat Sheet

Quick reference for all relevant local URLs in this repository.

Default ports shown below:

- `GATEWAY_PORT=8080`
- `AIRFLOW_PORT=8081`
- `GRAFANA_PORT=3001`
- `PROMETHEUS_PORT=9090`
- `LOKI_PORT=3100`
- `CLICKHOUSE_HTTP_PORT=8123`
- `CLICKHOUSE_NATIVE_PORT=9000`
- `MINIO_API_PORT=9100`
- `MINIO_CONSOLE_PORT=9001`

If you changed values in `.env`, replace the port numbers accordingly.

## External URLs (From Host Browser)

- Gateway root: http://localhost:8080
- Gateway health: http://localhost:8080/health
- Keycloak entrypoint (through gateway): http://localhost:8080/auth/
- Keycloak admin console: http://localhost:8080/auth/admin/master/console/

- API (through gateway): http://localhost:8080/api/
- Tracking API (through gateway): http://localhost:8080/tracking/
- Data API (through gateway): http://localhost:8080/data/
- Brain API (through gateway): http://localhost:8080/brain/

- Airflow UI: http://localhost:8081
- Grafana UI: http://localhost:3001
- Prometheus UI: http://localhost:9090
- Loki HTTP API base: http://localhost:3100

- ClickHouse HTTP API: http://localhost:8123
- ClickHouse Play UI: http://localhost:8123/play
- MinIO console: http://localhost:9001
- MinIO S3 API (host): http://localhost:9100

## Internal URLs (Container-to-Container)

Use these only from services running on the same Compose network.

- Keycloak realm issuer: http://keycloak:8080/realms/mspr
- Keycloak base: http://keycloak:8080/

- HealthBook API service: http://healthbook-api:3000/
- Tracking API service: http://tracking-api:3001/
- Data Recommendation API service: http://data-recommendation-api:3002/
- Brain NestJS API service: http://healthai-brain-nest-api:3003/
- Brain FastAPI service (internal only): http://healthai-brain-fastapi-api:8000/

- Postgres Keycloak: postgres_keycloak:5432
- Postgres API: postgres_api:5432
- Postgres Tracking: postgres_tracking:5432
- Postgres Data: postgres_data:5432
- Postgres Brain: postgres_brain:5432
- Postgres Airflow: postgres_airflow:5432

- Prometheus from Grafana: http://prometheus:9090
- Loki from Grafana: http://loki:3100
- Promtail metrics: http://promtail:9080/metrics

- ClickHouse HTTP API: http://clickhouse:8123
- ClickHouse native TCP: clickhouse:9000
- MinIO S3 API: http://minio:9000

## Profile Availability

- `core`: gateway, keycloak, postgres_keycloak
- `services`: healthbook-api, tracking-api, data-recommendation-api, healthai-brain-nest-api, healthai-brain-fastapi-api
- `data`: postgres_api, postgres_tracking, postgres_data, postgres_brain
- `airflow`: airflow-webserver, airflow-scheduler, airflow-init, postgres_airflow
- `monitoring`: grafana, prometheus, loki, promtail
- `deep-data`: clickhouse, minio

If a profile is not running, its URLs will not respond.
