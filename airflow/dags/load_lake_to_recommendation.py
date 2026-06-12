"""DAG `load_lake_to_recommendation` — Charge MinIO → API recommandation.

Réutilise le script `dump.py load <target>` pour insérer les datasets externes
stockés dans `lake/raw/external/` vers la base Postgres de `data-recommendation-api`.

Direction du flux :
    MinIO `lake/raw/external/` ──→ Postgres `data` (data-recommendation-api)

Pré-requis : avoir d'abord exécuté le DAG `seed_minio_datasets` (alias
`fetch_external`) qui dépose les datasets externes dans le lake.

Déclenchement manuel uniquement (`schedule=None`).
"""
from __future__ import annotations

from datetime import datetime

from airflow.decorators import dag
from airflow.operators.bash import BashOperator

DUMP_SCRIPT = "/opt/airflow/scripts/dump.py"
LOAD_TARGETS = ["food_item", "exercise", "diet"]


@dag(
    dag_id="load_lake_to_recommendation",
    schedule=None,
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["load", "postgres", "recommendation"],
    doc_md=__doc__,
)
def load_lake_to_recommendation():
    # Une task par dataset — exécutées en parallèle.
    BashOperator.partial(
        task_id="load_dataset",
    ).expand(
        bash_command=[f"python {DUMP_SCRIPT} load {target}" for target in LOAD_TARGETS],
    )


load_lake_to_recommendation()
