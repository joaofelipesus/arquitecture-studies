#!/usr/bin/env bash
# Samples real ids/titles/usernames from the database into k6/data/data.json for the k6 tests.
# Reads books_library_development by default; set DB to sample another database (run_load_tests.sh uses production).
# Run it before each load test: the user_books create pairs are consumed by the previous run.
set -euo pipefail

DB=${DB:-books_library_development}

cd "$(dirname "$0")"
mkdir -p data
# Write to a temp file first so a failed or interrupted query doesn't leave an empty data.json behind.
docker compose exec -T postgres psql -U postgres -d "$DB" -At -v ON_ERROR_STOP=1 -f - < data.sql > data/data.json.tmp
mv data/data.json.tmp data/data.json
echo "Wrote k6/data/data.json"
