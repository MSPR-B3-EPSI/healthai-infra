#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-healthai}"

PROFILES=(core services data monitoring airflow)
PROFILE_ARGS=()
for profile in "${PROFILES[@]}"; do
  PROFILE_ARGS+=(--profile "$profile")
done

docker compose \
  --project-name "${PROJECT_NAME}" \
  -f "${REPO_ROOT}/compose/compose.core.yaml" \
  -f "${REPO_ROOT}/compose/compose.services.yaml" \
  -f "${REPO_ROOT}/compose/compose.data.yaml" \
  -f "${REPO_ROOT}/compose/compose.airflow.yaml" \
  -f "${REPO_ROOT}/compose/compose.monitoring.yaml" \
  "${PROFILE_ARGS[@]}" \
  down
