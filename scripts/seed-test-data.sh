#!/usr/bin/env bash
#
# Insère des fake data IDENTIFIABLES dans `postgres_api` (healthbook) et
# `postgres_tracking`. Pour tester le cycle backup → restore : on peut
# vérifier après restore que ces marqueurs sont bien revenus.
#
# Usage :
#   ./scripts/seed-test-data.sh
#
# Marqueurs : tout est préfixé "BACKUP_TEST_" pour grep facile après restore.

set -euo pipefail

PROJECT="${COMPOSE_PROJECT_NAME:-healthai}"

API_CONTAINER="${PROJECT}-postgres_api-1"
API_USER="${API_POSTGRES_USER:-api}"
API_DB="${API_POSTGRES_DB:-api}"

TRACKING_CONTAINER="${PROJECT}-postgres_tracking-1"
TRACKING_USER="${TRACKING_POSTGRES_USER:-tracking}"
TRACKING_DB="${TRACKING_POSTGRES_DB:-tracking}"


echo "════════════════════════════════════════════════════════"
echo "  Seed fake data — healthbook + tracking"
echo "════════════════════════════════════════════════════════"

# ─── healthbook (User + Post) ────────────────────────────────────────────────
echo
echo "▶ healthbook : insert dans User + Post"
docker exec -i "$API_CONTAINER" psql -U "$API_USER" -d "$API_DB" <<'SQL'
INSERT INTO "User" (email, name) VALUES
  ('BACKUP_TEST_alice@example.com', 'BACKUP_TEST_Alice'),
  ('BACKUP_TEST_bob@example.com', 'BACKUP_TEST_Bob')
ON CONFLICT (email) DO NOTHING;

INSERT INTO "Post" (title, content, published, "authorId")
SELECT 'BACKUP_TEST_Post_Alice', 'contenu test', true, id
FROM "User" WHERE email = 'BACKUP_TEST_alice@example.com'
ON CONFLICT DO NOTHING;

SELECT 'healthbook' AS service,
       (SELECT count(*) FROM "User" WHERE email LIKE 'BACKUP_TEST_%') AS users_marqueurs,
       (SELECT count(*) FROM "Post" WHERE title LIKE 'BACKUP_TEST_%') AS posts_marqueurs;
SQL

# ─── tracking (WorkoutType + Member + Snapshot + Session) ─────────────────────
echo
echo "▶ tracking : insert dans workout_type + workout_member + snapshot + session"
docker exec -i "$TRACKING_CONTAINER" psql -U "$TRACKING_USER" -d "$TRACKING_DB" <<'SQL'
INSERT INTO workout_type (name, created_at, updated_at)
VALUES ('BACKUP_TEST_Yoga', now(), now())
ON CONFLICT (name) DO NOTHING;

INSERT INTO workout_member (gender, height_m, created_at, updated_at)
VALUES ('Male', 1.78, now(), now())
RETURNING id \gset
\echo Member créé : :id

INSERT INTO workout_subject_snapshot
  (member_id, age, weight_kg, fat_percentage, bmi, experience_level,
   workout_frequency_per_week, created_at, updated_at)
VALUES (:id, 30, 75, 18.5, 23.7, 2, 4, now(), now())
RETURNING id \gset

INSERT INTO workout_session
  (snapshot_id, workout_type_id, duration_hours, calories,
   avg_bpm, max_bpm, resting_bpm, water_intake_liters, created_at, updated_at)
VALUES (
  :id,
  (SELECT id FROM workout_type WHERE name = 'BACKUP_TEST_Yoga'),
  1.5, 350.0, 120, 165, 62, 0.75, now(), now()
);

SELECT 'tracking' AS service,
       (SELECT count(*) FROM workout_type WHERE name LIKE 'BACKUP_TEST_%') AS types_marqueurs,
       (SELECT count(*) FROM workout_member) AS members_total,
       (SELECT count(*) FROM workout_session) AS sessions_total;
SQL

echo
echo "✓ Seed terminé. Marqueurs insérés avec préfixe 'BACKUP_TEST_'."
echo "  → Lance maintenant un backup (Airflow DAG ou cron) puis teste le restore."
