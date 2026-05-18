from datetime import datetime

from airflow import DAG
from airflow.providers.docker.operators.docker import DockerOperator

NETWORK = "healthai_app"

MINIO_ENV = {
    "MINIO_ENDPOINT": "http://data-warehouse-minio-1:9000",
    "MINIO_ACCESS_KEY": "minioadmin",
    "MINIO_SECRET_KEY": "minio_password_change_me",
    "MINIO_BUCKET": "lake",
    "TRACKING_API_URL": "http://healthai-tracking-api-1:3001",
    "RECOMMENDATION_API_URL": "http://healthai-data-recommendation-api-1:3002",
}

# Commandes dump.py pour chaque source API (voir data-warehouse/dump-runner/dump.py)
API_DUMPS = ["food", "exercise", "diet"]

with DAG(
    dag_id="archive_api",
    start_date=datetime(2024, 1, 1),
    schedule_interval="*/15 * * * *",
    catchup=False,
    tags=["archive", "api"],
) as dag:
    for dataset in API_DUMPS:
        DockerOperator(
            task_id=f"dump_{dataset}",
            image="data-warehouse-dump-runner:latest",
            command=dataset,
            network_mode=NETWORK,
            environment=MINIO_ENV,
            mount_tmp_dir=False,
            auto_remove="success",
            docker_url="unix://var/run/docker.sock",
        )
