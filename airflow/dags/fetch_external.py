from __future__ import annotations

import io
import os
from datetime import datetime, timezone
from pathlib import Path

from airflow.decorators import dag, task
from minio import Minio

DATASETS_DIR = Path("/opt/airflow/datasets")
MINIO_BUCKET = os.environ.get("MINIO_BUCKET", "lake")

EXTERNAL_DATASETS = [
    {
        "dataset": "daily_food",
        "filename": "daily_food_nutrition_dataset.csv",
        "extension": "csv",
        "content_type": "text/csv",
    },
    {
        "dataset": "diet_recommendation",
        "filename": "diet_recommendations_dataset.csv",
        "extension": "csv",
        "content_type": "text/csv",
    },
    {
        "dataset": "exercise",
        "filename": "exercises.json",
        "extension": "json",
        "content_type": "application/json",
    },
    {
        "dataset": "workout_session",
        "filename": "gym_members_exercise_tracking.csv",
        "extension": "csv",
        "content_type": "text/csv",
    },
]


def _get_client() -> Minio:
    endpoint = os.environ.get("MINIO_ENDPOINT", "http://minio:9000")
    access_key = os.environ.get("MINIO_ROOT_USER", "minioadmin")
    secret_key = os.environ.get("MINIO_ROOT_PASSWORD", "change-me")
    bare = endpoint.replace("http://", "").replace("https://", "")
    return Minio(
        bare,
        access_key=access_key,
        secret_key=secret_key,
        secure=endpoint.startswith("https://"),
    )


def _put(client: Minio, key: str, data: bytes, content_type: str) -> None:
    client.put_object(
        bucket_name=MINIO_BUCKET,
        object_name=key,
        data=io.BytesIO(data),
        length=len(data),
        content_type=content_type,
    )


@dag(
    dag_id="seed_minio_datasets",
    schedule=None,
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["init", "minio"],
    doc_md="Upload `deep-data/datasets/` files to MinIO `lake/raw/external/` (versioned + `_latest`).",
)
def seed_minio_datasets():

    @task
    def ensure_bucket() -> None:
        client = _get_client()
        if not client.bucket_exists(MINIO_BUCKET):
            client.make_bucket(MINIO_BUCKET)

    @task
    def upload_dataset(
        dataset: str, filename: str, extension: str, content_type: str
    ) -> str:
        local_path = DATASETS_DIR / filename
        if not local_path.exists():
            raise FileNotFoundError(f"Dataset file not found: {local_path}")

        client = _get_client()
        data = local_path.read_bytes()
        label = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")
        base = f"raw/external/{dataset}"

        _put(client, f"{base}/{label}/data.{extension}", data, content_type)
        _put(client, f"{base}/_latest.{extension}", data, content_type)
        return f"{base}/{label}/ ({len(data):,} bytes)"

    bucket = ensure_bucket()
    uploads = upload_dataset.expand_kwargs(EXTERNAL_DATASETS)
    bucket >> uploads


seed_minio_datasets()
