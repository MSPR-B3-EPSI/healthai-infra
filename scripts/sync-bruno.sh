#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BRUNO_DIR="${REPO_ROOT}/bruno"

read_env_var() {
  local key="$1"
  if [[ -n "${!key:-}" ]]; then
    echo "${!key}"; return 0
  fi
  if [[ -f "${REPO_ROOT}/.env" ]]; then
    local value
    value="$(grep -E "^${key}=" "${REPO_ROOT}/.env" | tail -n1 || true)"
    if [[ -n "$value" ]]; then
      value="${value#*=}"; value="${value%\"}"; value="${value#\"}"; value="${value%\'}"; value="${value#\'}";
      echo "$value"; return 0
    fi
  fi
  return 1
}

GATEWAY_PORT="$(read_env_var GATEWAY_PORT || echo "8080")"
BASE="http://localhost:${GATEWAY_PORT}"

SERVICES=(
  "data-recommendation-api ${BASE}/data     data_api_url"
  "healthbook-api          ${BASE}/api      healthbook_api_url"
  "tracking-api            ${BASE}/tracking tracking_api_url"
)

for entry in "${SERVICES[@]}"; do
  read -r service base_url url_var <<< "$entry"
  spec_url="${base_url}/api-json"
  output_dir="${BRUNO_DIR}/${service}"

  echo "==> ${service}"

  spec="$(curl -sf "${spec_url}")" || {
    echo "  ✗ Could not reach ${spec_url} — is the service running?"
    continue
  }

  rm -rf "${output_dir}"

  seq=0
  while IFS=$'\t' read -r tag path method name has_body; do
    tag_dir="${output_dir}/${tag}"
    mkdir -p "${tag_dir}"

    seq=$(( seq + 1 ))
    url="{{${url_var}}}$(echo "${path}" | sed 's/{[^}]*}/:\0/g' | sed 's/:{/:/g; s/}//')"
    body_type=$( [[ "${has_body}" == "true" ]] && echo "json" || echo "none" )
    safe_name="$(echo "${name}" | tr -d '<>:"/\\|?*' | tr -s ' ')"

    {
      printf 'meta {\n  name: %s\n  type: http\n  seq: %d\n}\n' "${name}" "${seq}"
      printf '\n%s {\n  url: %s\n  body: %s\n  auth: inherit\n}\n' "${method}" "${url}" "${body_type}"
      if [[ "${has_body}" == "true" ]]; then
        printf '\nbody:json {\n  {\n  }\n}\n'
      fi
    } > "${tag_dir}/${safe_name}.bru"

    echo "  + ${tag}/${safe_name}.bru"
  done < <(echo "${spec}" | jq -r '
    .paths // {} | to_entries[] |
    .key as $path |
    .value | to_entries[] |
    select(.key | IN("get","post","put","patch","delete")) |
    {
      tag:     (.value.tags // ["default"])[0],
      path:    $path,
      method:  .key,
      name:    (.value.summary // (.key + " " + $path)),
      hasBody: (.key | IN("post","put","patch") | tostring)
    } |
    [ .tag, .path, .method, .name, .hasBody ] | @tsv
  ')

  echo "  ✓ written to ${output_dir}"
done
