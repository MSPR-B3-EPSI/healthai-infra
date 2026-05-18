import os
from datetime import datetime

from airflow import DAG
from airflow.providers.docker.operators.docker import DockerOperator
from docker.types import Mount

DATA_WAREHOUSE_HOST_DIR = os.environ.get(
    "DATA_WAREHOUSE_HOST_DIR", "/home/solweg/MSPR/data-warehouse"
)
CLICKHOUSE_PASSWORD = os.environ.get("CLICKHOUSE_PASSWORD", "healthbook")

NETWORK = "healthbook-net"
MINIO_ENV = {
    "MINIO_ENDPOINT": "http://minio:9000",
    "MINIO_ACCESS_KEY": "minioadmin",
    "MINIO_SECRET_KEY": "minio_password_change_me",
    "MINIO_BUCKET": "lake",
}

# Ordre d'exécution imposé par les dépendances inter-tables
ETL_SCRIPTS = [
    "load_daily_food.sql",
    "load_diet_recommendation.sql",
    "load_exercise_db.sql",
    "load_workout_session.sql",
]

with DAG(
    dag_id="etl_external",
    start_date=datetime(2024, 1, 1),
    schedule_interval="@daily",
    catchup=False,
    tags=["etl", "external"],
) as dag:

    dump_external = DockerOperator(
        task_id="dump_external",
        image="data-warehouse-dump-runner:latest",
        command="external",
        network_mode=NETWORK,
        environment=MINIO_ENV,
        mounts=[
            Mount(
                source=f"{DATA_WAREHOUSE_HOST_DIR}/datasets",
                target="/datasets",
                type="bind",
                read_only=True,
            )
        ],
        mount_tmp_dir=False,
        auto_remove="success",
        docker_url="unix://var/run/docker.sock",
    )

    etl_mount = Mount(
        source=f"{DATA_WAREHOUSE_HOST_DIR}/etl",
        target="/etl",
        type="bind",
        read_only=True,
    )

    prev = dump_external
    for script in ETL_SCRIPTS:
        task = DockerOperator(
            task_id=f"etl_{script.replace('.sql', '')}",
            image="clickhouse/clickhouse-server:latest",
            entrypoint="clickhouse-client",
            command=[
                "--host", "clickhouse",
                "--password", CLICKHOUSE_PASSWORD,
                "--queries-file", f"/etl/{script}",
            ],
            network_mode=NETWORK,
            mounts=[etl_mount],
            mount_tmp_dir=False,
            auto_remove="success",
            docker_url="unix://var/run/docker.sock",
        )
        prev >> task
        prev = task
