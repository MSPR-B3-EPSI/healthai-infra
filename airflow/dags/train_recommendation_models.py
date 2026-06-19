"""DAG `train_recommendation_models` — Réentraîne les modèles gym et diet.

Invoque `hidden-fastapi/scripts/train_recommendation.py` **dans le container
FastAPI** via `docker exec`. Même principe que `train_exercise_duration_model` :
pas de duplication des deps ML dans Airflow, sklearn identique entre train et serve.

Étapes du script :
    1. Gym  — charge `workout_session.raw_csv FINAL` depuis ClickHouse
              GradientBoostingRegressor → gym_model_v2.joblib / gym_scaler / gym_ohe
    2. Diet — charge `diet_recommendation.raw_diet FINAL` depuis ClickHouse
              GradientBoostingClassifier → diet_model_v2.joblib / diet_scaler / diet_ohe / diet_label_encoder

Artefacts sauvegardés dans `/workspace/recommendation/models/` (= hidden-fastapi/recommendation/models/
sur le host), chemin attendu par `recommendation/loader.py` au boot FastAPI.

Prérequis : container FastAPI actif + socket Docker host monté dans Airflow.
Déclenchement manuel uniquement (`schedule=None`).
"""
from __future__ import annotations

from datetime import datetime

from airflow.decorators import dag
from airflow.operators.bash import BashOperator

FASTAPI_CONTAINER    = "healthai-healthai-brain-fastapi-api-1"
TRAIN_SCRIPT         = "/workspace/scripts/train_recommendation.py"
PYTHON_BIN           = "/workspace/.venv/bin/python"


@dag(
    dag_id="train_recommendation_models",
    schedule=None,
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["train", "ml", "recommendation", "gym", "diet"],
    doc_md=__doc__,
)
def train_recommendation_models():
    BashOperator(
        task_id="train",
        bash_command=f"docker exec {FASTAPI_CONTAINER} {PYTHON_BIN} {TRAIN_SCRIPT}",
    )


train_recommendation_models()
