#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" != "--yes" ]]; then
  echo "WARNING: This will remove containers and ALL named volumes for this stack."
  echo "Run again with: ./scripts/reset.sh --yes"
  exit 1
fi

docker compose \
  -f compose/compose.core.yaml \
  -f compose/compose.services.yaml \
  -f compose/compose.data.yaml \
  -f compose/compose.airflow.yaml \
  -f compose/compose.monitoring.yaml \
  down -v
