"""DAG `load_warehouse` — MinIO (lake) → ClickHouse (warehouse).

Exécute en parallèle les 4 SQL `dags/sql/load_<dataset>.sql` (un par dataset).
Pour `workout_session`, un step amont garantit qu'un CSV header-only existe à
`lake/raw/api/workout_session/_latest.csv` (D16) — la section API du SQL utilise
`s3()` qui plante en 404 sur fichier absent.

Prérequis : `seed_minio_datasets` doit avoir tourné au moins une fois pour pousser
les datasets externes dans `lake/raw/external/`.
"""
from __future__ import annotations

import io
import os
import re
from datetime import datetime
from pathlib import Path

from airflow.decorators import dag, task
from clickhouse_driver import Client
from minio import Minio
from minio.error import S3Error

SQL_DIR = Path("/opt/airflow/dags/sql")
MINIO_BUCKET = os.environ.get("MINIO_BUCKET", "lake")

# D16 : CSV header-only à seeder dans MinIO pour que load_workout_session.sql
# tolère une tracking-api sans utilisateurs (sinon `s3()` retourne 404 dur).
WORKOUT_API_HEADER = (
    "age,gender,weight_kg,height_m,max_bpm,avg_bpm,resting_bpm,"
    "session_duration_hours,calories_burned,workout_type,fat_percentage,"
    "water_intake_liters,workout_frequency_days_week,experience_level,bmi"
)
WORKOUT_API_KEY = "raw/api/workout_session/_latest.csv"


def _ch_client() -> Client:
    return Client(
        host=os.environ.get("CLICKHOUSE_HOST", "clickhouse"),
        port=int(os.environ.get("CLICKHOUSE_PORT", "9000")),
        user=os.environ.get("CLICKHOUSE_USER", "default"),
        password=os.environ.get("CLICKHOUSE_PASSWORD", "change-me"),
    )


def _minio_client() -> Minio:
    endpoint = os.environ.get("MINIO_ENDPOINT", "http://minio:9000")
    bare = endpoint.replace("http://", "").replace("https://", "")
    return Minio(
        bare,
        access_key=os.environ.get("MINIO_ROOT_USER", "minioadmin"),
        secret_key=os.environ.get("MINIO_ROOT_PASSWORD", "change-me"),
        secure=endpoint.startswith("https://"),
    )


# TODO (dette technique) : parsing naïf — split sur ';' après strip des commentaires
# `--` et `/* */`. Les SQL du projet n'embarquent pas de ';' dans des littéraux,
# donc ça marche. Si un jour un statement contient un ';' dans une chaîne quotée,
# basculer sur `sqlparse.split()`.
def _split_sql(text: str) -> list[str]:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    text = re.sub(r"--[^\n]*", "", text)
    parts = [p.strip() for p in text.split(";")]
    return [p for p in parts if p]


def _run_sql_file(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(f"SQL file not found: {path}")
    client = _ch_client()
    statements = _split_sql(path.read_text(encoding="utf-8"))
    print(f"→ Executing {path.name} ({len(statements)} statements)")
    try:
        for idx, stmt in enumerate(statements, 1):
            preview = stmt.splitlines()[0][:80]
            print(f"  [{idx}/{len(statements)}] {preview}")
            client.execute(stmt)
    finally:
        client.disconnect()


@dag(
    dag_id="load_warehouse",
    schedule=None,
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["init", "clickhouse"],
    doc_md=__doc__,
)
def load_warehouse():

    @task
    def ensure_api_csv_header() -> str:
        """Idempotent : seed le CSV header-only seulement si absent.
        Préserve les vraies données quand `dump.py workout` aura tourné."""
        client = _minio_client()
        try:
            client.stat_object(MINIO_BUCKET, WORKOUT_API_KEY)
            return f"already exists at {MINIO_BUCKET}/{WORKOUT_API_KEY}"
        except S3Error as err:
            if err.code != "NoSuchKey":
                raise
            payload = (WORKOUT_API_HEADER + "\n").encode("utf-8")
            client.put_object(
                bucket_name=MINIO_BUCKET,
                object_name=WORKOUT_API_KEY,
                data=io.BytesIO(payload),
                length=len(payload),
                content_type="text/csv",
            )
            return f"seeded header-only ({len(payload)} bytes)"

    @task
    def load_dataset(dataset: str) -> str:
        _run_sql_file(SQL_DIR / f"load_{dataset}.sql")
        return f"loaded {dataset}"

    api_csv = ensure_api_csv_header()

    workout = load_dataset.override(task_id="load_workout_session")("workout_session")
    api_csv >> workout

    load_dataset.override(task_id="load_daily_food")("daily_food")
    load_dataset.override(task_id="load_diet_recommendation")("diet_recommendation")
    load_dataset.override(task_id="load_exercise_db")("exercise_db")


load_warehouse()
