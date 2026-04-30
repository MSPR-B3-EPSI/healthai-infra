# URL Cheat Sheet

Quick reference for all relevant local URLs in this repository.

Default ports shown below:

- `GATEWAY_PORT=8080`
- `AIRFLOW_PORT=8081`
- `GRAFANA_PORT=3001`
- `PROMETHEUS_PORT=9090`
- `LOKI_PORT=3100`
- `MINIO_PORT=9000`
- `MINIO_CONSOLE_PORT=9001`

If you changed values in `.env`, replace the port numbers accordingly.

## External URLs (From Host Browser)

- Gateway root: http://localhost:8080
- Gateway health: http://localhost:8080/api
- Keycloak entrypoint (through gateway): http://localhost:8080/auth/
- Keycloak admin console: http://localhost:8080/auth/admin/master/console/

- API (through gateway): http://localhost:8080/api/
- Tracking API (through gateway): http://localhost:8080/tracking/
- Data API (through gateway): http://localhost:8080/data/

- Airflow UI: http://localhost:8081
- Grafana UI: http://localhost:3001
- Prometheus UI: http://localhost:9090
- Loki HTTP API base: http://localhost:3100

## Internal URLs (Container-to-Container)

Use these only from services running on the same Compose network.

- Keycloak realm issuer: http://keycloak:8080/realms/mspr
- Keycloak base: http://keycloak:8080/

- HealthBook API service: http://healthbook-api:3000/
- Tracking API service: http://tracking-api:3000/
- Data Recommendation API service: http://data-recommendation-api:3000/

- Postgres Keycloak: postgres_keycloak:5432
- Postgres API: postgres_api:5432
- Postgres Tracking: postgres_tracking:5432
- Postgres Data: postgres_data:5432
- Postgres Airflow: postgres_airflow:5432

- Prometheus from Grafana: http://prometheus:9090
- Loki from Grafana: http://loki:3100
- Promtail metrics: http://promtail:9080/metrics

## Profile Availability

- `core`: gateway, keycloak, postgres_keycloak
- `services`: healthbook-api, tracking-api, data-recommendation-api
- `data`: postgres_api, postgres_tracking, postgres_data, minio
- `airflow`: airflow-webserver, airflow-scheduler, airflow-init, postgres_airflow
- `monitoring`: grafana, prometheus, loki, promtail

If a profile is not running, its URLs will not respond.
