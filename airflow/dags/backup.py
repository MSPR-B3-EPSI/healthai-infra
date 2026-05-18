import requests
from datetime import datetime

from airflow import DAG
from airflow.operators.python import PythonOperator

# Le scheduler est sur healthbook-net (voir compose.airflow.yaml)
CLICKHOUSE_HTTP_URL = "http://clickhouse:8123/"
CLICKHOUSE_PASSWORD = "healthbook"
MINIO_ENDPOINT = "http://minio:9000"
MINIO_KEY = "minioadmin"
MINIO_SECRET = "minio_password_change_me"

DATABASES = ["exercise_db", "daily_food", "diet_recommendation", "workout_session"]


def backup_database(db_name: str, ts_nodash: str) -> None:
    backup_path = f"{MINIO_ENDPOINT}/lake/backup/clickhouse/{ts_nodash}/{db_name}/"
    query = (
        f"BACKUP DATABASE {db_name} "
        f"TO S3('{backup_path}', '{MINIO_KEY}', '{MINIO_SECRET}')"
    )
    resp = requests.post(
        CLICKHOUSE_HTTP_URL,
        data=query,
        params={"password": CLICKHOUSE_PASSWORD},
        timeout=300,
    )
    resp.raise_for_status()
    print(f"✓ {db_name} → {backup_path}")


with DAG(
    dag_id="backup",
    start_date=datetime(2024, 1, 1),
    schedule_interval="@daily",
    catchup=False,
    tags=["backup"],
) as dag:
    for db in DATABASES:
        PythonOperator(
            task_id=f"backup_{db}",
            python_callable=backup_database,
            op_kwargs={"db_name": db, "ts_nodash": "{{ ts_nodash }}"},
        )
