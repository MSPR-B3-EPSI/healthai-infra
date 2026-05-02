#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-healthai}"

COMPOSE_FILES=(
  -f "${REPO_ROOT}/compose/compose.core.yaml"
  -f "${REPO_ROOT}/compose/compose.services.yaml"
  -f "${REPO_ROOT}/compose/compose.data.yaml"
  -f "${REPO_ROOT}/compose/compose.airflow.yaml"
  -f "${REPO_ROOT}/compose/compose.monitoring.yaml"
)

ALL_SERVICES=(healthbook-api tracking-api data-recommendation-api)

if [[ $# -eq 0 ]]; then
  TARGETS=("${ALL_SERVICES[@]}")
else
  TARGETS=()
  for target in "$@"; do
    case "$target" in
      healthbook-api|tracking-api|data-recommendation-api)
        TARGETS+=("$target")
        ;;
      *)
        echo "Unknown service: $target" >&2
        echo "Allowed values: ${ALL_SERVICES[*]}" >&2
        exit 1
        ;;
    esac
  done
fi

for service in "${TARGETS[@]}"; do
  echo "==> npm install in $service"
  docker compose --project-name "${PROJECT_NAME}" "${COMPOSE_FILES[@]}" exec "$service" npm install
done
