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

# Waits until postgres-replica has replayed everything the primary has written so far.
wait_for_replica() {
  local lsn
  lsn=$(psql -At -c "SELECT pg_current_wal_lsn()")
  until [ "$(docker compose exec -T postgres-replica psql -U postgres -At -c "SELECT pg_last_wal_replay_lsn() >= '$lsn'")" = t ]; do
    sleep 1
  done
}

# setup env for testing (the app instances are stopped while the database is replaced)
docker compose stop "${APPS[@]}"
docker compose up -d postgres postgres-replica
until docker compose exec -T postgres pg_isready -U postgres -q; do sleep 1; done
until docker compose exec -T postgres-replica pg_isready -U postgres -q; do sleep 1; done

# create the production role (CREATEDB lets db:prepare create the queue/cable databases)
psql <<SQL
DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$DB_USER') THEN CREATE ROLE $DB_USER LOGIN CREATEDB; END IF;
END \$\$;
SQL

# restore the database. WAL stays on (no wal_level=minimal shortcut): postgres-replica copies the restore by
# replaying it, and a standby can't replay WAL written at the minimal level.
# drop the solid queue/cable databases too, so db:prepare recreates them empty when the app boots
for db in "$DB" "${DB}_queue" "${DB}_cable"; do
  psql -c "DROP DATABASE IF EXISTS $db WITH (FORCE)"
done
psql -c "CREATE DATABASE $DB OWNER $DB_USER"
# restore as the app's role so it owns every table
docker compose exec -T postgres pg_restore -U "$DB_USER" -d "$DB" --single-transaction --no-owner --no-privileges < k6/restore.dump
# the dump comes from development; mark it as production so Rails' protected environment checks apply
psql -d "$DB" -c "UPDATE ar_internal_metadata SET value = 'production' WHERE key = 'environment'" -c "ANALYZE"

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

# make sure the replica has the whole restore and the migrations the apps ran on boot before the test starts
wait_for_replica

# run tests on k6
docker compose run --rm k6 run tests/complete.js
