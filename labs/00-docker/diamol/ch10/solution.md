# Solution

## Steps

- from `exercises` directory:
  - copy the `.env`, `docker-compose.yml`, `docker-compose-dev.yml`, and `docker-compose-test.yml` files.
  - copy the `config/` directory

## `.env`

- default env: `COMPOSE_FILE=docker-compose.yml;docker-compose-dev.yml`
- default port: `TODO_WEB_PORT=8089`
- default project name: `TODO_PROJECT_NAME=todo-app`

## docker compose file for DEV

- new image version: `image: diamol/ch06-todo-list:2e-v2`
- port hard coded to `8089`
- local db -> no need to setup `todo-db`
  - but `secrets` needs to be passed in `./config/empty.json` to `todo-db-connection`

## docker compose file for TEST

- `todo-web`
  - use Postgres database: `Database:Provider=Postgres`
  - connect with the config file under `secrets` field

- `todo-db` container
  - port is handled by `.env` setting
  - declare a named volume `todo-database`
  - mount volume to `todo-db` container at `/data`
    - `volumes`: `"todo-database:/data"`
  - config PostgreSQL to use `/data` as its data directory
    - `environment`: `PGDATA=/data`
