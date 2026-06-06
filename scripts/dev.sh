#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
  echo "This script requires bash." >&2
  echo "Run it as: ./scripts/dev.sh ... or bash scripts/dev.sh ..." >&2
  exit 1
fi

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

read_env_var() {
  local key="$1"
  local value=""

  if [[ -n "${!key:-}" ]]; then
    echo "${!key}"
    return 0
  fi

  if [[ -f "${REPO_ROOT}/.env" ]]; then
    value="$(grep -E "^${key}=" "${REPO_ROOT}/.env" | tail -n1 || true)"
    if [[ -n "$value" ]]; then
      value="${value#*=}"
      value="${value%\"}"
      value="${value#\"}"
      value="${value%\'}"
      value="${value#\'}"
      echo "$value"
      return 0
    fi
  fi

  return 1
}

resolve_source_dir() {
  local service="$1"
  case "$service" in
    healthbook-api)
      read_env_var MSPR_API_SOURCE_DIR || echo "${REPO_ROOT}/../healthbook-api"
      ;;
    tracking-api)
      read_env_var MSPR_TRACKING_SOURCE_DIR || echo "${REPO_ROOT}/../tracking-api"
      ;;
    data-recommendation-api)
      read_env_var MSPR_DATA_SOURCE_DIR || echo "${REPO_ROOT}/../data-recommendation-api"
      ;;
    healthai-brain-nest-api)
      read_env_var MSPR_BRAIN_NEST_SOURCE_DIR || echo "${REPO_ROOT}/../healthai-brain-api/exposed-nest-api"
      ;;
    healthai-brain-fastapi-api)
      read_env_var MSPR_BRAIN_FASTAPI_SOURCE_DIR || echo "${REPO_ROOT}/../healthai-brain-api/hidden-fastapi"
      ;;
    *)
      return 1
      ;;
  esac
}

ALL_SERVICES=(healthbook-api tracking-api data-recommendation-api healthai-brain-nest-api healthai-brain-fastapi-api)

if [[ $# -eq 0 ]]; then
  TARGETS=("${ALL_SERVICES[@]}")
else
  TARGETS=()
  for target in "$@"; do
    valid=0
    for svc in "${ALL_SERVICES[@]}"; do
      [[ "$target" == "$svc" ]] && valid=1 && break
    done
    if [[ $valid -eq 0 ]]; then
      echo "Unknown service: $target" >&2
      echo "Allowed values: ${ALL_SERVICES[*]}" >&2
      exit 1
    fi
    TARGETS+=("$target")
  done
fi

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "No dev services selected." >&2
  echo "Use: ./scripts/dev.sh [${ALL_SERVICES[*]}]" >&2
  exit 1
fi

for target in "${TARGETS[@]}"; do
  src_dir="$(resolve_source_dir "$target")"
  if [[ ! -d "$src_dir" ]]; then
    echo "Source directory not found for $target: $src_dir" >&2
    echo "Set the matching MSPR_*_SOURCE_DIR env var before running dev mode." >&2
    exit 1
  fi
done

# Start infrastructure profiles without requiring service images.
docker compose --project-name "${PROJECT_NAME}" "${COMPOSE_FILES[@]}" --profile core --profile data --profile monitoring --profile airflow --profile deep-data up -d
docker compose --project-name "${PROJECT_NAME}" "${COMPOSE_FILES[@]}" --profile core --profile data --profile services up -d "${TARGETS[@]}"