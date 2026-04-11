#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILES=(
  -f compose/compose.core.yaml
  -f compose/compose.services.yaml
  -f compose/compose.data.yaml
  -f compose/compose.airflow.yaml
  -f compose/compose.monitoring.yaml
)

if [[ $# -eq 0 ]]; then
  PROFILES=(core services data monitoring airflow)
else
  PROFILES=("$@")
fi

PROFILE_ARGS=()
for profile in "${PROFILES[@]}"; do
  PROFILE_ARGS+=(--profile "$profile")
done

docker compose "${COMPOSE_FILES[@]}" "${PROFILE_ARGS[@]}" up -d
