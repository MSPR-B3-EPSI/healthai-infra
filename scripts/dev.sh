#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
  echo "This script requires bash." >&2
  echo "Run it as: ./scripts/dev.sh ... or bash scripts/dev.sh ..." >&2
  exit 1
fi

set -euo pipefail

COMPOSE_FILES=(
  -f compose/compose.core.yaml
  -f compose/compose.services.yaml
  -f compose/compose.data.yaml
  -f compose/compose.airflow.yaml
  -f compose/compose.monitoring.yaml
)

DEV_COMPOSE_FILE=compose/compose.services.dev.yaml

WITH_IMAGE_SERVICES=false

read_env_var() {
  local key="$1"
  local value=""

  if [[ -n "${!key:-}" ]]; then
    echo "${!key}"
    return 0
  fi

  if [[ -f .env ]]; then
    value="$(grep -E "^${key}=" .env | tail -n1 || true)"
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
    mspr_api)
      read_env_var MSPR_API_SOURCE_DIR || echo "../mspr-api"
      ;;
    mspr_tracking)
      read_env_var MSPR_TRACKING_SOURCE_DIR || echo "../mspr-tracking"
      ;;
    mspr_data)
      read_env_var MSPR_DATA_SOURCE_DIR || echo "../mspr-data"
      ;;
    *)
      return 1
      ;;
  esac
}

if [[ $# -eq 0 ]]; then
  TARGETS=(mspr_api mspr_tracking mspr_data)
else
  TARGETS=()
  for target in "$@"; do
    case "$target" in
      --with-images)
        WITH_IMAGE_SERVICES=true
        ;;
      mspr_api|mspr_tracking|mspr_data)
        TARGETS+=("$target")
        ;;
      *)
        echo "Unknown service: $target" >&2
        echo "Allowed values: mspr_api, mspr_tracking, mspr_data, --with-images" >&2
        exit 1
        ;;
    esac
  done
fi

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "No dev services selected." >&2
  echo "Use: ./scripts/dev.sh [--with-images] mspr_api [mspr_tracking] [mspr_data]" >&2
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
docker compose "${COMPOSE_FILES[@]}" --profile core --profile data --profile monitoring --profile airflow up -d

if [[ "$WITH_IMAGE_SERVICES" == "true" ]]; then
  IMAGE_SERVICES=()
  for service in mspr_api mspr_tracking mspr_data; do
    keep_image=true
    for target in "${TARGETS[@]}"; do
      if [[ "$service" == "$target" ]]; then
        keep_image=false
        break
      fi
    done
    if [[ "$keep_image" == "true" ]]; then
      IMAGE_SERVICES+=("$service")
    fi
  done

  if [[ ${#IMAGE_SERVICES[@]} -gt 0 ]]; then
    docker compose "${COMPOSE_FILES[@]}" --profile services up -d "${IMAGE_SERVICES[@]}"
  fi
fi

docker compose "${COMPOSE_FILES[@]}" -f "$DEV_COMPOSE_FILE" --profile services up -d "${TARGETS[@]}"