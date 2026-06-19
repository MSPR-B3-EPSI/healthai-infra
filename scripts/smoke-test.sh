#!/usr/bin/env bash
#
# Smoke test — vérifie que les endpoints critiques de la stack HealthAI
# répondent après un `dev.sh`. Conçu pour être appelé par Jenkins (et par
# n'importe quel dev qui veut valider sa stack locale).
#
# Usage :
#   ./scripts/smoke-test.sh             # test tous les endpoints
#   ./scripts/smoke-test.sh --quiet     # n'affiche que les échecs
#
# Exit code :
#   0   tous les endpoints répondent
#   1   au moins un endpoint a échoué après tous les retries
#
# Comportement :
# - Chaque endpoint est retesté jusqu'à `MAX_RETRIES` fois avec `RETRY_DELAY`
#   secondes entre les tentatives (les containers prennent du temps à booter).
# - Le test est résilient : un endpoint qui répond "200 OK" passe, même si le
#   corps de la réponse est inattendu.

set -uo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────

MAX_RETRIES="${MAX_RETRIES:-12}"      # 12 × 10s = 2 min max par endpoint
RETRY_DELAY="${RETRY_DELAY:-10}"
TIMEOUT="${TIMEOUT:-5}"
QUIET="${1:-}"

# ─── Ports configurables (depuis .env, sinon defaults dev local) ─────────────
# Si tu lances depuis Jenkins, source le .env avant : `set -a; . ./.env; set +a`
HOST="${HOST:-localhost}"
GATEWAY_PORT="${GATEWAY_PORT:-8080}"             # Nginx gateway (proxy vers keycloak + APIs)
AIRFLOW_PORT="${AIRFLOW_PORT:-8081}"             # Airflow webserver
CLICKHOUSE_HTTP_PORT="${CLICKHOUSE_HTTP_PORT:-8123}"
MINIO_API_PORT="${MINIO_API_PORT:-9100}"
MINIO_CONSOLE_PORT="${MINIO_CONSOLE_PORT:-9001}"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
GRAFANA_PORT="${GRAFANA_PORT:-3001}"

# Couleurs (désactivées si stdout n'est pas un terminal — utile dans Jenkins)
if [[ -t 1 ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  BLUE=$'\033[0;34m'
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; RESET=''
fi


# ─── Liste des endpoints à tester ─────────────────────────────────────────────
# Format : "name|url|expected_status|optional_grep_pattern"
# - expected_status : code HTTP attendu (default 200)
# - grep_pattern : si présent, le body doit matcher (regex grep)

ENDPOINTS=(
  "Gateway Nginx (brain/docs)|http://${HOST}:${GATEWAY_PORT}/brain/docs|200|"
  "Keycloak (realm healthai)|http://${HOST}:${GATEWAY_PORT}/auth/realms/healthai/.well-known/openid-configuration|200|issuer"
  "Airflow webserver|http://${HOST}:${AIRFLOW_PORT}/health|200|healthy"
  "ClickHouse HTTP|http://${HOST}:${CLICKHOUSE_HTTP_PORT}/ping|200|Ok"
  "MinIO API health|http://${HOST}:${MINIO_API_PORT}/minio/health/live|200|"
  "MinIO Console|http://${HOST}:${MINIO_CONSOLE_PORT}/|200|"
  "Prometheus|http://${HOST}:${PROMETHEUS_PORT}/-/healthy|200|Healthy"
  "Grafana|http://${HOST}:${GRAFANA_PORT}/api/health|200|database"
)


# ─── Helpers ──────────────────────────────────────────────────────────────────

log() {
  if [[ "$QUIET" != "--quiet" ]]; then
    echo "$@"
  fi
}

# Teste un endpoint avec retries. Retourne 0 si OK, 1 sinon.
check_endpoint() {
  local name="$1"
  local url="$2"
  local expected_status="${3:-200}"
  local grep_pattern="${4:-}"

  local attempt=0
  local status
  local body
  local response_time_ms

  while [[ $attempt -lt $MAX_RETRIES ]]; do
    attempt=$((attempt + 1))

    # `-w` formatage : code HTTP + temps de réponse en ms
    # `-s` silent, `-S` show errors, `--max-time` timeout par tentative
    response=$(curl -sS -o /tmp/smoke-body.txt -w "%{http_code}|%{time_total}" \
      --max-time "$TIMEOUT" \
      "$url" 2>/tmp/smoke-err.txt) || true

    status="${response%%|*}"
    time_s="${response##*|}"
    response_time_ms=$(awk "BEGIN {printf \"%.0f\", $time_s * 1000}" 2>/dev/null || echo "?")

    if [[ "$status" == "$expected_status" ]]; then
      # Vérif optionnelle du body
      if [[ -n "$grep_pattern" ]]; then
        if grep -q "$grep_pattern" /tmp/smoke-body.txt 2>/dev/null; then
          log "  ${GREEN}✓${RESET} ${BOLD}${name}${RESET}  ${status}  (${response_time_ms}ms, try ${attempt}/${MAX_RETRIES})"
          return 0
        fi
        # Status OK mais body ne matche pas : on retente
      else
        log "  ${GREEN}✓${RESET} ${BOLD}${name}${RESET}  ${status}  (${response_time_ms}ms, try ${attempt}/${MAX_RETRIES})"
        return 0
      fi
    fi

    # Pas la dernière tentative → on attend et on retente
    if [[ $attempt -lt $MAX_RETRIES ]]; then
      log "  ${YELLOW}⋯${RESET} ${name}  (try ${attempt}/${MAX_RETRIES}, got '${status:-?}', retry in ${RETRY_DELAY}s)"
      sleep "$RETRY_DELAY"
    fi
  done

  # Tous les retries épuisés
  echo "  ${RED}✗${RESET} ${BOLD}${name}${RESET}  ${url}  (last status: '${status:-no response}')"
  if [[ -s /tmp/smoke-err.txt ]]; then
    echo "    curl error: $(head -c 200 /tmp/smoke-err.txt)"
  fi
  return 1
}


# ─── Main ─────────────────────────────────────────────────────────────────────

log "${BOLD}${BLUE}════════════════════════════════════════════════════════${RESET}"
log "${BOLD}${BLUE}  HealthAI smoke test${RESET}"
log "${BOLD}${BLUE}  $(date -Iseconds)${RESET}"
log "${BOLD}${BLUE}════════════════════════════════════════════════════════${RESET}"
log

failed=0
passed=0

for endpoint in "${ENDPOINTS[@]}"; do
  IFS='|' read -r name url expected_status grep_pattern <<< "$endpoint"
  if check_endpoint "$name" "$url" "$expected_status" "$grep_pattern"; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
done

log
log "${BOLD}${BLUE}════════════════════════════════════════════════════════${RESET}"
total=$((passed + failed))
if [[ $failed -eq 0 ]]; then
  log "${GREEN}${BOLD}✓ All ${total} endpoints OK${RESET}"
  exit 0
else
  echo "${RED}${BOLD}✗ ${failed}/${total} endpoints failed${RESET}"
  exit 1
fi
