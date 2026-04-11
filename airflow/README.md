# Airflow (Local Dev)

This profile provides:

- `postgres_airflow` metadata database
- `airflow-init` for DB migration and admin user creation
- `airflow-webserver`
- `airflow-scheduler`

DAGs should represent scheduler jobs such as archival, backup, restore, and ETL.
