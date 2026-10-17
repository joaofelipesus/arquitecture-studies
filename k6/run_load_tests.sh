#!/usr/bin/env bash
# Runs the app in production mode, restores the production database from k6/restore.dump and runs the k6 load test against it.
# The app instances stay in production mode afterwards; `docker compose up -d app app2 app3 app4` (without RAILS_ENV) switches them back to development.
# Regenerate the dump from the current dev database with:
#   docker compose exec -T postgres pg_dump -U postgres -d books_library_development -Fc --compress=zstd:level=19,long --no-owner --no-privileges > k6/restore.dump
set -euo pipefail

cd "$(dirname "$0")/.."

# Every docker compose call below (and in prepare_data.sh) sees this, so compose never recreates the app in development mode.
export RAILS_ENV=production
export DB=books_library_production
APPS=(app app2 app3 app4)
APP_PORTS=(3000 3002 3003 3004) # host ports of the app instances, in the same order
DB_USER=books_library # production username in config/database.yml (Postgres uses trust auth, so no password)

psql() { docker compose exec -T postgres psql -U postgres -v ON_ERROR_STOP=1 -q "$@"; }

restart_postgres() {
  docker compose restart postgres
  until docker compose exec -T postgres pg_isready -U postgres -q; do sleep 1; done
}

# Postgres can't fully disable WAL. wal_level=minimal lets the single-transaction restore skip WAL for the
# tables it creates, and turning off fsync/full_page_writes/synchronous_commit removes the rest of the disk syncs.
wal_off() {
  psql -c "ALTER SYSTEM SET wal_level = minimal" -c "ALTER SYSTEM SET max_wal_senders = 0" \
       -c "ALTER SYSTEM SET fsync = off" -c "ALTER SYSTEM SET full_page_writes = off" -c "ALTER SYSTEM SET synchronous_commit = off"
  restart_postgres
}

wal_on() {
  psql -c "ALTER SYSTEM RESET wal_level" -c "ALTER SYSTEM RESET max_wal_senders" \
       -c "ALTER SYSTEM RESET fsync" -c "ALTER SYSTEM RESET full_page_writes" -c "ALTER SYSTEM RESET synchronous_commit"
  restart_postgres
}

# setup env for testing (the app instances are stopped while Postgres restarts and the database is replaced)
docker compose stop "${APPS[@]}"
docker compose up -d postgres
until docker compose exec -T postgres pg_isready -U postgres -q; do sleep 1; done

# create the production role (CREATEDB lets db:prepare create the queue/cable databases)
psql <<SQL
DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$DB_USER') THEN CREATE ROLE $DB_USER LOGIN CREATEDB; END IF;
END \$\$;
SQL

# restore the database with WAL off, turning it back on even if the restore fails
wal_off
trap wal_on EXIT
# drop the solid queue/cable databases too, so db:prepare recreates them empty when the app boots
for db in "$DB" "${DB}_queue" "${DB}_cable"; do
  psql -c "DROP DATABASE IF EXISTS $db WITH (FORCE)"
done
psql -c "CREATE DATABASE $DB OWNER $DB_USER"
# restore as the app's role so it owns every table
docker compose exec -T postgres pg_restore -U "$DB_USER" -d "$DB" --single-transaction --no-owner --no-privileges < k6/restore.dump
# the dump comes from development; mark it as production so Rails' protected environment checks apply
psql -d "$DB" -c "UPDATE ar_internal_metadata SET value = 'production' WHERE key = 'environment'" -c "ANALYZE"
trap - EXIT
wal_on

# start the app instances in production mode, the load balancer and the metrics stack, and wait for them to answer
docker compose up -d "${APPS[@]}" nginx prometheus grafana
for port in "${APP_PORTS[@]}"; do
  until curl -sf -o /dev/null "http://localhost:$port/up"; do sleep 2; done
done
until curl -sf -o /dev/null http://localhost:8000/up; do sleep 1; done

# sample real ids/titles/usernames for the tests
k6/prepare_data.sh

# start every run with an empty Redis (cache and Kredis keys), so a previous run's cache doesn't speed this one up
docker compose exec -T redis redis-cli FLUSHALL

# run tests on k6
docker compose run --rm k6 run tests/complete.js
