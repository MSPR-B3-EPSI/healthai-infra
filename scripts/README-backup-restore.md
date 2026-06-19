# Backup + Restore — Procédure de test end-to-end

Validation manuelle du cycle complet : **seed → backup → wipe → restore → verify**.

## Pré-requis

- Tous les containers UP : `docker compose ... up -d`
- L'image Airflow custom buildée (avec `postgresql-client`) : `docker compose ... build airflow-init`
- Les containers Airflow recréés après le build

## Procédure complète

### 1. Insert fake data identifiables

```bash
./scripts/seed-test-data.sh
```

Insère :
- **healthbook** : 2 users + 1 post avec préfixe `BACKUP_TEST_`
- **tracking** : 1 type d'entraînement + 1 member + 1 snapshot + 1 session avec préfixe `BACKUP_TEST_`

À la fin, le script affiche un récap des marqueurs insérés.

### 2. Déclencher le backup manuellement

Dans l'UI Airflow ([http://localhost:8081](http://localhost:8081)) :
- Aller sur le DAG `backup_dbs_to_lake`
- Cliquer **Trigger DAG**
- Attendre que les 3 tasks (healthbook, tracking, keycloak) passent au vert

### 3. Vérifier que les dumps sont dans MinIO

```bash
docker exec healthai-minio-1 mc ls -r local/lake/backups/
```

Doit afficher au minimum :
```
backups/healthbook/_latest.sql.gz
backups/healthbook/<timestamp>/dump.sql.gz
backups/tracking/_latest.sql.gz
backups/tracking/<timestamp>/dump.sql.gz
backups/keycloak/_latest.sql.gz
backups/keycloak/<timestamp>/dump.sql.gz
```

### 4. Simuler une perte de données

Pour healthbook :
```bash
docker exec healthai-postgres_api-1 psql -U api -d api \
  -c "DELETE FROM \"User\" WHERE email LIKE 'BACKUP_TEST_%'"
```

Pour tracking :
```bash
docker exec healthai-postgres_tracking-1 psql -U tracking -d tracking \
  -c "DELETE FROM workout_session; DELETE FROM workout_subject_snapshot; DELETE FROM workout_member; DELETE FROM workout_type WHERE name LIKE 'BACKUP_TEST_%';"
```

Vérifier que les marqueurs sont partis :
```bash
docker exec healthai-postgres_api-1 psql -U api -d api \
  -c "SELECT count(*) FROM \"User\" WHERE email LIKE 'BACKUP_TEST_%'"
# → 0
```

### 5. Restaurer

```bash
./scripts/restore-db-from-lake.sh healthbook
# Confirmer en tapant 'yes'
```

Puis :
```bash
./scripts/restore-db-from-lake.sh tracking
```

### 6. Vérifier que les marqueurs sont revenus

```bash
docker exec healthai-postgres_api-1 psql -U api -d api \
  -c "SELECT email, name FROM \"User\" WHERE email LIKE 'BACKUP_TEST_%'"
# → 2 lignes (Alice + Bob)

docker exec healthai-postgres_tracking-1 psql -U tracking -d tracking \
  -c "SELECT name FROM workout_type WHERE name LIKE 'BACKUP_TEST_%'"
# → 1 ligne (BACKUP_TEST_Yoga)
```

## Restorer une version antérieure

Par défaut le script restaure le `_latest.sql.gz`. Pour restaurer un snapshot daté précis :

```bash
# Lister les versions disponibles dans MinIO
docker exec healthai-minio-1 mc ls local/lake/backups/healthbook/

# Restorer une version précise
./scripts/restore-db-from-lake.sh healthbook 2026-06-17T03-00-00Z
```

## Restaurer Keycloak (cas spécial)

Keycloak doit être **stoppé** avant le restore (il garde des connexions actives qui bloquent le DROP SCHEMA) :

```bash
docker stop healthai-keycloak-1
./scripts/restore-db-from-lake.sh keycloak
docker start healthai-keycloak-1
```

## ⚠️ Notes importantes

- **Le restore wipe totalement le schema public** de la DB cible. Toute donnée non backupée est perdue.
- **L'ordre des restores compte** si les DBs ont des liens (pas le cas chez nous, chaque API a sa DB isolée).
- **Tester régulièrement** : un backup non testé = pas de backup. Faire ce cycle E2E avant chaque démo critique.

---

## 🆘 Disaster Recovery — MinIO daemon HS

Si MinIO ne répond plus (container crashé, panne réseau), on peut quand même
récupérer les backups directement depuis le **volume Docker** sur l'host. MinIO
stocke chaque objet comme un dossier contenant le fichier brut dans `part.1`.

```bash
# Layout sur l'host (lecture root requise)
sudo ls /var/lib/docker/volumes/healthai_minio_data/_data/lake/backups/

# Le fichier brut s'appelle TOUJOURS `part.1` à l'intérieur du dossier de l'objet
sudo cp /var/lib/docker/volumes/healthai_minio_data/_data/lake/backups/healthbook/_latest.sql.gz/part.1 \
  /tmp/dump.sql.gz

# Restore comme d'habitude (Postgres doit tourner)
gunzip < /tmp/dump.sql.gz | docker exec -i healthai-postgres_api-1 psql -U api -d api
```

**Cette procédure ne protège PAS contre** : perte de disque, suppression du
volume Docker, compromission machine. Pour une vraie résilience face à ces
cas, il faudrait une **réplication offsite** (autre datacenter ou cloud S3) —
hors scope du POC.
