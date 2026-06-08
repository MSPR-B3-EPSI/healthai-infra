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
  -f "${REPO_ROOT}/compose/compose.deep_data.yaml"
)

# Named volumes per service (without project prefix — prefix is added at runtime).
# Services not listed here have no named volumes; they can still be reset (container only).
declare -A SERVICE_VOLUMES=(
  ["postgres_keycloak"]="pgdata_keycloak"
  ["postgres_api"]="pgdata_api"
  ["postgres_tracking"]="pgdata_tracking"
  ["postgres_data"]="pgdata_data"
  ["postgres_brain"]="pgdata_brain"
  ["postgres_airflow"]="pgdata_airflow"
  ["healthai-brain-fastapi-api"]="brain_venv brain_hf_cache"
  ["grafana"]="grafana_data"
  ["promtail"]="promtail_positions"
  ["clickhouse"]="clickhouse_data"
  ["minio"]="minio_data"
)

usage() {
  echo "Usage:"
  echo "  ./scripts/reset.sh --yes                    Full reset — remove all containers and named volumes"
  echo "  ./scripts/reset.sh --yes <service> [...]    Per-service reset — remove container(s) and their named volumes"
  echo ""
  echo "Services with named volumes:"
  for svc in $(echo "${!SERVICE_VOLUMES[@]}" | tr ' ' '\n' | sort); do
    printf "  %-40s %s\n" "$svc" "${SERVICE_VOLUMES[$svc]}"
  done
}

if [[ "${1:-}" != "--yes" ]]; then
  echo "WARNING: This will remove containers and named volumes."
  echo ""
  usage
  exit 1
fi

shift  # consume --yes

if [[ $# -eq 0 ]]; then
  # Full stack reset
  PROFILE_ARGS=(--profile core --profile services --profile data --profile monitoring --profile airflow --profile deep-data)
  echo "Resetting full stack…"
  docker compose --project-name "${PROJECT_NAME}" "${COMPOSE_FILES[@]}" "${PROFILE_ARGS[@]}" down -v
  exit 0
fi

# Per-service reset
for service in "$@"; do
  echo "==> Resetting ${service}"

  docker compose --project-name "${PROJECT_NAME}" "${COMPOSE_FILES[@]}" stop "${service}" 2>/dev/null || true
  docker compose --project-name "${PROJECT_NAME}" "${COMPOSE_FILES[@]}" rm -f "${service}" 2>/dev/null || true

  if [[ -n "${SERVICE_VOLUMES[${service}]:-}" ]]; then
    for vol in ${SERVICE_VOLUMES[${service}]}; do
      full_vol="${PROJECT_NAME}_${vol}"
      if docker volume inspect "${full_vol}" &>/dev/null; then
        docker volume rm "${full_vol}"
        echo "  removed volume: ${full_vol}"
      else
        echo "  volume already absent: ${full_vol}"
      fi
    done
  else
    echo "  no named volumes — container removed, nothing else to clean"
  fi
done

echo ""
echo "Done. Restart affected profiles with: ./scripts/up.sh <profiles>"
