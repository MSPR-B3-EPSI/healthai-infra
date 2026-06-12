"""DAG `dump_api_to_lake` — Sauvegarde l'état des APIs dans MinIO.

Réutilise le script `dump.py` (déjà éprouvé en CLI) pour archiver l'état actuel
des 4 endpoints `/export` des deux APIs vers `lake/raw/api/<source>/`.

Direction du flux :
    tracking-api          ──┐
    data-recommendation-api ┴──→  MinIO `lake/raw/api/...`

Déclenchement manuel uniquement (`schedule=None`) — on rebranchera un cron plus tard.
"""
from __future__ import annotations

from datetime import datetime

from airflow.decorators import dag
from airflow.operators.bash import BashOperator

DUMP_SCRIPT = "/opt/airflow/scripts/dump.py"
DUMP_SUBCOMMANDS = ["workout", "food", "exercise", "diet"]


@dag(
    dag_id="dump_api_to_lake",
    schedule=None,
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["dump", "minio", "api"],
    doc_md=__doc__,
)
def dump_api_to_lake():
    # Une task par sous-commande — Airflow les exécute en parallèle.
    BashOperator.partial(
        task_id="dump_source",
    ).expand(
        bash_command=[f"python {DUMP_SCRIPT} {sub}" for sub in DUMP_SUBCOMMANDS],
    )


dump_api_to_lake()
