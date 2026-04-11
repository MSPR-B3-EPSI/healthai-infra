#!/usr/bin/env bash
set -euo pipefail

docker compose \
  -f compose/compose.core.yaml \
  -f compose/compose.services.yaml \
  -f compose/compose.data.yaml \
  -f compose/compose.airflow.yaml \
  -f compose/compose.monitoring.yaml \
  down
