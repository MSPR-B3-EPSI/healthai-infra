"""DAG `train_exercise_duration_model` — Réentraîne le modèle de durée de séance.

Invoque `hidden-fastapi/scripts/train.py` **dans le container FastAPI** via
`docker exec`. Avantages : pas de duplication des deps ML dans Airflow, et même
version de sklearn pour train et serve (évite les pickle/joblib incompatibles).

Étapes du script :
    1. Charge `workout_session.session FINAL` depuis ClickHouse
    2. Entraîne le pipeline `StandardScaler + LinearRegression` (D19)
    3. Écrit `/workspace/model/latest.joblib` (+ daté + features.json)
    4. Upload `latest.joblib` vers MinIO `lake/models/exercise_duration/`

Pré-requis : le container FastAPI tourne (`docker compose up -d healthai-brain-fastapi-api`)
et le socket Docker du host est monté dans Airflow (cf. compose.airflow.yaml).

Déclenchement manuel uniquement (`schedule=None`). Migration future envisagée
vers `DockerOperator` (apache-airflow-providers-docker).
"""
from __future__ import annotations

from datetime import datetime

from airflow.decorators import dag
from airflow.operators.bash import BashOperator

FASTAPI_CONTAINER = "healthai-healthai-brain-fastapi-api-1"
TRAIN_SCRIPT_IN_CONTAINER = "/workspace/scripts/train.py"
# Important : on utilise le Python **du venv** (pas /usr/local/bin/python du système),
# sinon `import clickhouse_connect/sklearn/minio` échoue (packages installés dans .venv).
PYTHON_BIN_IN_CONTAINER = "/workspace/.venv/bin/python"


@dag(
    dag_id="train_exercise_duration_model",
    schedule=None,
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["train", "ml", "exercise"],
    doc_md=__doc__,
)
def train_exercise_duration_model():
    BashOperator(
        task_id="train",
        bash_command=f"docker exec {FASTAPI_CONTAINER} {PYTHON_BIN_IN_CONTAINER} {TRAIN_SCRIPT_IN_CONTAINER}",
    )


train_exercise_duration_model()
