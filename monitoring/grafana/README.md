# Grafana Provisioning

This folder provisions Grafana datasources and dashboards automatically:

- Prometheus datasource at `http://prometheus:9090`
- Loki datasource at `http://loki:3100`
- Dashboard provider loading JSON from `monitoring/grafana/dashboards`

Main dashboard placeholder: `monitoring/grafana/dashboards/mspr-overview.json`.
