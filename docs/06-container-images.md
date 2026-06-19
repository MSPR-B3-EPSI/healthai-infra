# Container Images

## Purpose

This document describes every container image used by the stack: what each image contains,
how it is configured, and which best practices are or are not currently applied. Use it when
adding a new image, editing a Dockerfile, or reviewing image security/size concerns.

## Two Ways Images Are Used Here

1. **Infra dev mode** (`compose/compose.services.yaml`, started by `scripts/up.sh` and
   `scripts/dev.sh`): runs the stock `node:22-bookworm-slim` and `python:3.11-slim` images
   directly, with the service source bind-mounted from `MSPR_*_SOURCE_DIR`. The container
   installs dependencies and starts the app via the `command:` field
   (`MSPR_*_DEV_COMMAND` in `.env`). The per-service Dockerfiles described below are **not**
   used in this mode.
2. **Standalone per-service mode**: `healthbook-api`, `tracking-api`, and
   `data-recommendation-api` each ship their own `docker-compose.yml` with `build: .`, which
   builds and runs that service's own Dockerfile against its own dedicated Postgres container,
   independent of the infra network. `healthai-brain-api/exposed-nest-api/Dockerfile` and
   `healthai-brain-api/hidden-fastapi/Dockerfile` exist but currently have no standalone
   `docker-compose.yml` wiring them up — they are only there to build images manually or by CI/CD.

Keep this distinction in mind: editing a service's Dockerfile has no effect on the infra
dev-mode stack, only on that service's standalone build.

## Custom-Built Images

| Service                    | Dockerfile                                       | Base image              | Build context                          | Exposed port           |
| -------------------------- | ------------------------------------------------ | ----------------------- | -------------------------------------- | ---------------------- |
| healthbook-api             | `healthbook-api/Dockerfile`                      | `node:22-bookworm-slim` | `healthbook-api/`                      | 3000                   |
| tracking-api               | `tracking-api/Dockerfile`                        | `node:22-bookworm-slim` | `tracking-api/`                        | 3001                   |
| data-recommendation-api    | `data-recommendation-api/Dockerfile`             | `node:22-bookworm-slim` | `data-recommendation-api/`             | 3002                   |
| healthai-brain-nest-api    | `healthai-brain-api/exposed-nest-api/Dockerfile` | `node:22-bookworm-slim` | `healthai-brain-api/exposed-nest-api/` | 3003                   |
| healthai-brain-fastapi-api | `healthai-brain-api/hidden-fastapi/Dockerfile`   | `python:3.11-slim`      | `healthai-brain-api/hidden-fastapi/`   | 8000                   |
| healthai-airflow:custom    | `healthai-infra/airflow/Dockerfile`              | `apache/airflow:2.9.3`  | `healthai-infra/airflow/`              | inherits Airflow ports |

### NestJS + Prisma services (healthbook-api, tracking-api, data-recommendation-api, healthai-brain-nest-api)

All four follow the same pattern:

```
FROM node:22-bookworm-slim
WORKDIR /workspace
COPY package*.json ./
RUN npm install
COPY . .
RUN npx prisma generate
EXPOSE <service port>
CMD ["sh", "-c", "npx prisma generate && npx prisma db push && npm run start:dev"]
```

- Single-stage build: `devDependencies` and the npm cache remain in the final image.
- Runs as root — no `USER` directive.
- The baked-in `CMD` is dev-oriented: it pushes the Prisma schema directly to the database
  (no migration history) and starts Nest in watch mode (`start:dev`), not a production build.
- No `.dockerignore` in any of these build contexts, so `.git`, local `node_modules`, and any
  `dist/` are sent to the Docker build context unless manually absent.

### healthai-brain-fastapi-api (hidden-fastapi)

```
FROM python:3.11-slim
WORKDIR /workspace
RUN useradd --create-home appuser
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN chown -R appuser:appuser /workspace
EXPOSE 8000
USER appuser
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

- The only custom image in this repo that drops root for runtime (`appuser`).
- `pip install --no-cache-dir` avoids caching wheel files in the layer.
- `CMD` has no `--reload`, unlike the infra dev-mode command for this service
  (`MSPR_BRAIN_FASTAPI_DEV_COMMAND` adds `--reload`) — this image's own `CMD` is closer to a
  production start than the Node images' `CMD`s are.

### healthai-airflow:custom

```
FROM apache/airflow:2.9.3
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
USER airflow
```

- Adds `postgresql-client` (for `pg_dump`, used by the `backup_dbs_to_lake` DAG) on top of the
  official Airflow image, then drops back to the `airflow` user.
- Built once and shared by `airflow-init`, `airflow-webserver`, and `airflow-scheduler` in
  `compose/compose.airflow.yaml`, all tagged `healthai-airflow:custom`.
- Python dependencies from `airflow/requirements.txt` are **not** baked into this image — the
  webserver and scheduler `command:` blocks run `pip install -r requirements.txt` at container
  start, so editing `requirements.txt` only requires a container restart, not an image rebuild.

## Off-The-Shelf Images (No Custom Dockerfile)

| Image:tag                             | Role                                                                                                                                                | Configured via                                                     |
| ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| `postgres:16`                         | per-service DB in the infra stack (`postgres_keycloak`, `postgres_api`, `postgres_tracking`, `postgres_data`, `postgres_brain`, `postgres_airflow`) | `POSTGRES_*` env vars                                              |
| `postgres:15`                         | DB for each service's standalone `docker-compose.yml`                                                                                               | `.env` in the service repo                                         |
| `nginx:1.27-alpine`                   | gateway / reverse proxy                                                                                                                             | `nginx/nginx.conf`, `conf.d`, `snippets`, `static`                 |
| `quay.io/keycloak/keycloak:26.0`      | auth server                                                                                                                                         | `keycloak/realm` import, `KC_*` env vars                           |
| `prom/prometheus:v2.55.1`             | metrics                                                                                                                                             | `monitoring/prometheus/prometheus.yml`                             |
| `grafana/loki:3.2.1`                  | log storage                                                                                                                                         | `monitoring/loki/loki-config.yaml`                                 |
| `grafana/grafana:11.2.2`              | dashboards                                                                                                                                          | `monitoring/grafana/provisioning`, `monitoring/grafana/dashboards` |
| `grafana/promtail:3.2.1`              | log shipping                                                                                                                                        | `monitoring/promtail/promtail-config.yaml`                         |
| `clickhouse/clickhouse-server:latest` | analytics warehouse                                                                                                                                 | `deep-data/clickhouse/init`, `config.d`, `users.d`                 |
| `minio/minio:latest`                  | object storage / data lake                                                                                                                          | `MINIO_ROOT_*` env vars                                            |
| `node:22-bookworm-slim`               | runs service source directly in infra dev mode (no build)                                                                                           | `command:` + bind mount in `compose.services.yaml`                 |
| `python:3.11-slim`                    | runs Brain FastAPI source directly in infra dev mode (no build)                                                                                     | `command:` + bind mount in `compose.services.yaml`                 |

## Persistent Volumes Tied to Images

- `brain_venv`: persists the FastAPI dev container's Python venv so PyTorch isn't reinstalled
  on every start.
- `brain_hf_cache`: persists HuggingFace model weights across restarts.
- `node_modules` anonymous volume (standalone per-service `docker-compose.yml` files): shadows
  the bind-mounted source so the container's own installed `node_modules` isn't overwritten by
  the host directory.

## Best Practices Because of Current liabilities — Current Gaps and Recommendations

Here are some recommendations about the current state of the project.
We can say that theses emanates from weakness of the current way of doing things

1. **No `.dockerignore` anywhere.** None of `healthbook-api/`, `tracking-api/`,
   `data-recommendation-api/`, `healthai-brain-api/exposed-nest-api/`,
   `healthai-brain-api/hidden-fastapi/`, or `healthai-infra/airflow/` has one. Add one excluding
   `node_modules`, `.git`, `dist`, `.env`, and `*.log` to shrink the build context and avoid
   leaking local artifacts into the image.
2. **`npm install` instead of `npm ci`.** All four Node Dockerfiles use `npm install`. Switch
   to `npm ci` to install strictly from the committed lockfile — faster, reproducible, and it
   fails loudly if `package-lock.json` is out of sync instead of silently resolving anyway.
3. **No multi-stage builds.** The Node images keep `devDependencies` and the npm cache in the
   final layer. If any of these images is meant to run outside dev-watch mode, add a builder
   stage (`npm ci && npm run build`) and a final stage (`npm ci --omit=dev` + copy `dist/`).
4. **Root by default.** Only `hidden-fastapi` drops to a non-root user (`appuser`). Add an
   equivalent `USER node` step to the four Node Dockerfiles.
5. **Dev command baked into the image `CMD`.** All four Node Dockerfiles run
   `npm run start:dev` (watch mode, `prisma db push`) as their container `CMD`. If these images
   are meant for the standalone/image-mode path, the `CMD` should run a production start
   (`start:prod` against a built `dist/`, with `prisma migrate deploy` instead of `db push`),
   leaving watch mode to the infra repo's dev profile only.
6. **Floating tags.** `clickhouse/clickhouse-server:latest` and `minio/minio:latest` are
   unpinned, unlike every other infra image (`postgres:16`, `keycloak:26.0`,
   `prometheus:v2.55.1`, etc.). Pin them to a specific released tag so a fresh
   `docker compose pull` can't silently change behavior.
7. **Default secrets in `.env.example`.** `change-me` and `admin`/`admin` defaults are fine for
   local dev but must never be reused if any of these compose files are adapted for a
   non-local environment.
8. **Airflow Python deps installed at container start, not at build time.** This means a
   restart can pick up a different dependency resolution than the last one. Baking
   `requirements.txt` into the custom Airflow image build would make scheduler/webserver
   startup reproducible, at the cost of needing an image rebuild per dependency change.

## Rebuilding Images

Rebuild the shared custom Airflow image after editing `healthai-infra/airflow/Dockerfile`:

```bash
docker compose -f compose/compose.airflow.yaml build airflow-init
```

Build and run a service in standalone mode from its own repo:

```bash
cd ../healthbook-api
docker compose build healthbook-api
docker compose up -d
```
