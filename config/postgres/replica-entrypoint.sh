#!/usr/bin/env bash
# Entrypoint of the `postgres-replica` service (docker-compose.yml): a read-only streaming replica of `postgres`.
# On a boot with an empty data directory it copies the primary with pg_basebackup; -R writes standby.signal and the
# connection settings, so Postgres starts as a standby that keeps replaying the primary's WAL.
set -euo pipefail

PRIMARY_HOST=postgres
SLOT=replica

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  until pg_isready -h "$PRIMARY_HOST" -U postgres -q; do sleep 1; done

  # The slot makes the primary keep the WAL the replica hasn't received yet (bounded by max_slot_wal_keep_size),
  # so a burst of writes (like the load test restore) can't outrun it.
  psql -h "$PRIMARY_HOST" -U postgres -v ON_ERROR_STOP=1 -q \
    -c "SELECT pg_create_physical_replication_slot('$SLOT') WHERE NOT EXISTS (SELECT FROM pg_replication_slots WHERE slot_name = '$SLOT')"

  # The volume's root can't be removed, only emptied.
  find "$PGDATA" -mindepth 1 -delete
  pg_basebackup -h "$PRIMARY_HOST" -U postgres -D "$PGDATA" -S "$SLOT" -R -X stream -c fast
  chmod 700 "$PGDATA"
fi

exec postgres
