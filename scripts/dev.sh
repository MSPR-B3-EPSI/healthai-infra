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
    *)
      return 1
      ;;
  esac
}

if [[ $# -eq 0 ]]; then
  TARGETS=(healthbook-api tracking-api data-recommendation-api)
else
  TARGETS=()
  for target in "$@"; do
    case "$target" in
      healthbook-api|tracking-api|data-recommendation-api)
        TARGETS+=("$target")
        ;;
      *)
        echo "Unknown service: $target" >&2
        echo "Allowed values: healthbook-api, tracking-api, data-recommendation-api" >&2
        exit 1
        ;;
    esac
  done
fi

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "No dev services selected." >&2
  echo "Use: ./scripts/dev.sh healthbook-api [tracking-api] [data-recommendation-api]" >&2
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
docker compose --project-name "${PROJECT_NAME}" "${COMPOSE_FILES[@]}" --profile core --profile data --profile monitoring --profile airflow up -d
docker compose --project-name "${PROJECT_NAME}" "${COMPOSE_FILES[@]}" --profile core --profile data --profile services up -d "${TARGETS[@]}"