"""DAG `backup_dbs_to_lake` — Backup quotidien des DBs Postgres vers MinIO.

Pour chaque service ciblé, le DAG :
    1. exécute `pg_dump` depuis le container Airflow (image custom avec
       `postgresql-client` — cf. `airflow/Dockerfile`)
    2. compresse le SQL avec gzip en mémoire
    3. upload dans MinIO :
        - snapshot daté : `lake/backups/<service>/<YYYY-MM-DDTHH-MM-SSZ>/dump.sql.gz`
        - alias stable  : `lake/backups/<service>/_latest.sql.gz`

Schedule : tous les jours à **3h du matin UTC** (creux d'activité utilisateur).

Services backupés :
    - `healthbook` : DB `postgres_api` (utilisée par `healthbook-api`)
    - `tracking`   : DB `postgres_tracking` (utilisée par `tracking-api`,
       aussi appelée "workout-api")
    - `keycloak`   : DB `postgres_keycloak` (auth + realms + users)
"""
from __future__ import annotations

import gzip
import io
import os
import subprocess
from datetime import datetime, timezone

from airflow.decorators import dag, task
from minio import Minio


# ─── Cibles à backuper ───────────────────────────────────────────────────────

BACKUP_TARGETS = [
    {
        "service": "healthbook",
        "host": "postgres_api",
        "port": "5432",
        "user_env": "API_POSTGRES_USER",
        "password_env": "API_POSTGRES_PASSWORD",
        "db_env": "API_POSTGRES_DB",
    },
    {
        "service": "tracking",
        "host": "postgres_tracking",
        "port": "5432",
        "user_env": "TRACKING_POSTGRES_USER",
        "password_env": "TRACKING_POSTGRES_PASSWORD",
        "db_env": "TRACKING_POSTGRES_DB",
    },
    {
        "service": "keycloak",
        "host": "postgres_keycloak",
        "port": "5432",
        "user_env": "KC_POSTGRES_USER",
        "password_env": "KC_POSTGRES_PASSWORD",
        "db_env": "KC_POSTGRES_DB",
    },
]


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _get_minio() -> Minio:
    endpoint = os.environ["MINIO_ENDPOINT"].replace("http://", "").replace("https://", "")
    return Minio(
        endpoint,
        access_key=os.environ["MINIO_ACCESS_KEY"],
        secret_key=os.environ["MINIO_SECRET_KEY"],
        secure=False,
    )


def _pg_dump(host: str, port: str, user: str, password: str, db: str) -> bytes:
    """Lance `pg_dump` et retourne le SQL brut en bytes (non compressé).

    On utilise `--no-owner --no-acl` pour produire un dump portable
    (réimportable dans une autre DB sans soucis de roles/permissions).
    """
    env = {**os.environ, "PGPASSWORD": password}
    result = subprocess.run(
        [
            "pg_dump",
            "-h", host, "-p", port, "-U", user, "-d", db,
            "--no-owner", "--no-acl",
        ],
        env=env,
        check=True,
        capture_output=True,
    )
    return result.stdout


def _upload_dump(client: Minio, bucket: str, service: str, gz_bytes: bytes) -> str:
    """Upload dans MinIO : version datée + alias `_latest.sql.gz`."""
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")
    dated_key = f"backups/{service}/{timestamp}/dump.sql.gz"
    latest_key = f"backups/{service}/_latest.sql.gz"

    for key in (dated_key, latest_key):
        client.put_object(
            bucket_name=bucket,
            object_name=key,
            data=io.BytesIO(gz_bytes),
            length=len(gz_bytes),
            content_type="application/gzip",
        )
    return dated_key


# ─── DAG ──────────────────────────────────────────────────────────────────────

@dag(
    dag_id="backup_dbs_to_lake",
    schedule="0 3 * * *",   # 3h UTC chaque jour
    start_date=datetime(2026, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=["backup", "postgres", "minio"],
    doc_md=__doc__,
)
def backup_dbs_to_lake():

    @task
    def dump_and_upload(target: dict) -> str:
        service = target["service"]
        user = os.environ[target["user_env"]]
        password = os.environ[target["password_env"]]
        db = os.environ[target["db_env"]]

        print(f"[{service}] pg_dump {target['host']}:{target['port']}/{db} (user={user})")
        sql_bytes = _pg_dump(target["host"], target["port"], user, password, db)
        gz_bytes = gzip.compress(sql_bytes, compresslevel=6)
        print(f"[{service}] dump : {len(sql_bytes) / 1024:.1f} kB → gz : {len(gz_bytes) / 1024:.1f} kB")

        client = _get_minio()
        bucket = os.environ.get("MINIO_BUCKET", "lake")
        if not client.bucket_exists(bucket):
            client.make_bucket(bucket)

        dated_key = _upload_dump(client, bucket, service, gz_bytes)
        print(f"[{service}] ✓ upload MinIO {bucket}/{dated_key}")
        return f"{service} → {dated_key} ({len(gz_bytes) / 1024:.1f} kB)"

    dump_and_upload.expand(target=BACKUP_TARGETS)


backup_dbs_to_lake()
