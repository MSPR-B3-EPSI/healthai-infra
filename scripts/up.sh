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

ENV_ARGS=()
if [[ -f "${REPO_ROOT}/.env" ]]; then
  ENV_ARGS+=(--env-file "${REPO_ROOT}/.env")
fi

if [[ $# -eq 0 ]]; then
  PROFILES=(core services data monitoring airflow)
else
  PROFILES=("$@")
fi

PROFILE_ARGS=()
for profile in "${PROFILES[@]}"; do
  PROFILE_ARGS+=(--profile "$profile")
done

docker compose --project-name "${PROJECT_NAME}" "${ENV_ARGS[@]}" "${COMPOSE_FILES[@]}" "${PROFILE_ARGS[@]}" up -d
