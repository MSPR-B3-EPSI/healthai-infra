"""DAG `train_exercise_duration_model` — Réentraîne le modèle de durée de séance.

Invoque le script autonome `ml/exercise/scripts/train.py` qui :
    1. Charge `workout_session.session FINAL` depuis ClickHouse
    2. Entraîne le pipeline `StandardScaler + LinearRegression` (D19)
    3. Écrit `model/latest.joblib` (+ une copie datée + métadonnées JSON)

Le `.joblib` est écrit dans le volume `ml/exercise/model/` qui est aussi monté
en read-only dans le container FastAPI — celui-ci recharge automatiquement le
modèle au prochain redémarrage (la lifespan loader lit `latest.joblib`).

Déclenchement manuel uniquement (`schedule=None`).
"""
from __future__ import annotations

from datetime import datetime

from airflow.decorators import dag
from airflow.operators.bash import BashOperator

TRAIN_SCRIPT = "/opt/airflow/ml_exercise/scripts/train.py"


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
        bash_command=f"python {TRAIN_SCRIPT}",
    )


train_exercise_duration_model()
