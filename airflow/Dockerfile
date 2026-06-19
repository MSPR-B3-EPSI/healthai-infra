# Image Airflow étendue avec postgresql-client.
#
# Ajout : binaire `pg_dump` (paquet `postgresql-client`) pour les DAGs de
# backup (cf. dags/backup_dbs_to_lake.py). Le pip install des deps Python
# reste fait au boot du container via le `command` du compose.
#
# L'image officielle Airflow ne contient PAS postgresql-client par défaut.
# On ajoute le paquet en root puis on rebascule sur le user `airflow`.

FROM apache/airflow:2.9.3

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
USER airflow
