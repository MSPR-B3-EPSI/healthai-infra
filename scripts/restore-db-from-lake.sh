#!/usr/bin/env bash
#
# Restaure une DB Postgres depuis un backup stocké dans MinIO (data lake).
#
# Pipeline : MinIO → gunzip → psql, sans fichier temporaire local autre que
# `/tmp/<service>-dump.sql.gz` (supprimé en fin de script).
#
# Usage :
#   ./scripts/restore-db-from-lake.sh <service> [version]
#
# Arguments :
#   service : healthbook | tracking | keycloak
#   version : (optionnel)
#             - "latest" (défaut) → `_latest.sql.gz`
#             - "<timestamp>" (ex: 2026-06-17T03-00-00Z) → `<timestamp>/dump.sql.gz`
#
# Exemples :
#   ./scripts/restore-db-from-lake.sh healthbook
#   ./scripts/restore-db-from-lake.sh tracking 2026-06-17T03-00-00Z
#
# ⚠️ Le restore **WIPE** entièrement le schema `public` de la DB cible
# (DROP SCHEMA public CASCADE) avant import. Une confirmation est demandée.

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <service> [version]" >&2
  echo "  service : healthbook | tracking | keycloak" >&2
  echo "  version : 'latest' (défaut) ou un timestamp '2026-...-...'" >&2
  exit 1
fi

SERVICE="$1"
VERSION="${2:-latest}"
PROJECT="${COMPOSE_PROJECT_NAME:-healthai}"

# ─── Mapping service → container / user / db ─────────────────────────────────
case "$SERVICE" in
  healthbook)
    PG_CONTAINER="${PROJECT}-postgres_api-1"
    PG_USER="${API_POSTGRES_USER:-api}"
    PG_DB="${API_POSTGRES_DB:-api}"
    ;;
  tracking)
    PG_CONTAINER="${PROJECT}-postgres_tracking-1"
    PG_USER="${TRACKING_POSTGRES_USER:-tracking}"
    PG_DB="${TRACKING_POSTGRES_DB:-tracking}"
    ;;
  keycloak)
    PG_CONTAINER="${PROJECT}-postgres_keycloak-1"
    PG_USER="${KC_POSTGRES_USER:-keycloak}"
    PG_DB="${KC_POSTGRES_DB:-keycloak}"
    ;;
  *)
    echo "Service inconnu : $SERVICE (choisir : healthbook | tracking | keycloak)" >&2
    exit 1
    ;;
esac

# ─── Construction du chemin MinIO ────────────────────────────────────────────
MINIO_BUCKET="${MINIO_BUCKET:-lake}"
if [[ "$VERSION" == "latest" ]]; then
  S3_KEY="backups/${SERVICE}/_latest.sql.gz"
else
  S3_KEY="backups/${SERVICE}/${VERSION}/dump.sql.gz"
fi

TMP_DUMP="/tmp/${SERVICE}-restore.sql.gz"
MINIO_ACCESS_KEY="${MINIO_ROOT_USER:-minioadmin}"
MINIO_SECRET_KEY="${MINIO_ROOT_PASSWORD:-change-me}"

# ─── Récap + confirmation ────────────────────────────────────────────────────
cat <<EOF

════════════════════════════════════════════════════════
  Restore DB depuis le lake
════════════════════════════════════════════════════════

  Service       : $SERVICE
  Version       : $VERSION
  Source MinIO  : ${MINIO_BUCKET}/${S3_KEY}
  Container     : $PG_CONTAINER
  DB cible      : $PG_DB (user $PG_USER)

⚠️  Le schema 'public' de '$PG_DB' va être WIPE puis remplacé.
    Toutes les données actuelles seront PERDUES.

EOF

read -p "Continuer ? Taper 'yes' pour confirmer : " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "Annulé."
  exit 0
fi

# ─── 1. Download depuis MinIO via container minio/mc ad-hoc ───────────────────
# `mc cat` stream le contenu vers stdout, qu'on redirige vers un fichier local.
# L'alias mc est nommé "minio" pour éviter la confusion avec le bucket "lake".
echo
echo "▶ 1/3 Download depuis MinIO…"
docker run --rm \
  --network "${PROJECT}_app" \
  -e "MC_HOST_minio=http://${MINIO_ACCESS_KEY}:${MINIO_SECRET_KEY}@minio:9000" \
  minio/mc cat "minio/${MINIO_BUCKET}/${S3_KEY}" \
  > "$TMP_DUMP"

size_kb=$(du -k "$TMP_DUMP" | awk '{print $1}')
echo "  ✓ Téléchargé : $TMP_DUMP (${size_kb} kB)"

# ─── 2. Wipe + restore via container postgres ────────────────────────────────
echo
echo "▶ 2/3 Wipe du schema 'public' de '$PG_DB'…"
docker exec "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" \
  -c "DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;" \
  > /dev/null
echo "  ✓ Schema wiped"

echo
echo "▶ 3/3 Restore via psql…"
gunzip < "$TMP_DUMP" | docker exec -i "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" \
  > /tmp/restore-${SERVICE}.log 2>&1
echo "  ✓ Restore exécuté (log : /tmp/restore-${SERVICE}.log)"

# ─── 4. Cleanup ───────────────────────────────────────────────────────────────
rm -f "$TMP_DUMP"

echo
echo "✓ Restore terminé pour '$SERVICE'. Vérifie les marqueurs avec :"
echo "  docker exec ${PG_CONTAINER} psql -U ${PG_USER} -d ${PG_DB} -c \"<une SELECT pour valider>\""
