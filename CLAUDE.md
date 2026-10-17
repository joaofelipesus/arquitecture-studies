# CLAUDE.md

Books Library: a Rails 8.1 API-only app (`config.api_only = true`) on Ruby 3.4.6 and PostgreSQL 17.

## Rails generators

**Use Rails generators whenever a request can be fulfilled by one** (scaffold, model, migration, controller, scaffold_controller, resource, job, mailer, etc.) instead of hand-writing the files. Run the generator first, then edit the generated output as needed.

- New model only: `bin/rails g model Book title:string description:text release_date:date`
- CRUD endpoints for an existing model: `bin/rails g scaffold_controller Book title:string ...` (adds `resources` route + controller tests)
- Model + CRUD from scratch: `bin/rails g scaffold ...`
- Schema changes: `bin/rails g migration AddFooToBooks foo:string`

Run generators inside the app container (see below) so they use the project's Ruby/gems.

## Dev environment (Docker)

Development runs via `docker-compose.yml` + `Dockerfile.dev` (the root `Dockerfile` is the production/Kamal image — don't use it for dev).

- Start: `docker compose up -d` (app on http://localhost:3000, three more instances `app2`/`app3`/`app4` on http://localhost:3002/3003/3004, an nginx load balancer in front of all four on http://localhost:8000 (`config/nginx/nginx.conf`, round-robin), Postgres on host port 5433, to avoid clashing with other local Postgres instances, and Redis on host port 6380, limited to 500 MB with a 400 MB `maxmemory` and LRU eviction, no persistence). Redis databases: 0 for Kredis (`REDIS_URL`, `config/redis/shared.yml`), 1 for the production `Rails.cache` (`REDIS_CACHE_URL`), 2 for Kredis in tests (`REDIS_TEST_URL`). `app2`–`app4` wait for `app` to be healthy, since `app` installs the gems and runs `db:prepare`.
- Run any Rails command: `docker compose exec app bin/rails <cmd>`
- Gems live in the `gems` volume; `bundle install` runs on container start.
- Import the catalog CSVs (books, users and user_books must be empty; it runs in one transaction): `docker compose exec app bin/rails import:catalog` (reads the git-ignored CSVs in `lib/tasks/data/`; pass `"import:catalog[other/dir]"` to use another folder). The logic lives in `lib/import.rb`.
- Load tests (k6): `k6/run_load_tests.sh` does the whole run: restarts the app in production mode (`RAILS_ENV=production`, which compose passes to the app; it stays that way until a plain `docker compose up -d app`), restores `books_library_production` (owned by the `books_library` role, which the script creates) from the versioned `k6/restore.dump` (pg_dump custom format of the dev DB, with WAL turned off during the restore and back on after), samples test data, empties Redis, and runs `tests/complete.js`. Previous runs' results stay in Prometheus, so the Grafana dashboards keep their history (pick the run's time range). The script header has the command to regenerate the dump. Scripts live in `k6/tests/`. To run a test by hand, run `k6/prepare_data.sh` first (samples real ids/titles/usernames from the dev DB, or from the DB named in `DB`, into the git-ignored `k6/data/data.json`; re-run it before each test since `user_books` create consumes its pairs), then `docker compose run --rm k6 run tests/complete.js` (the `k6` service is behind the `load-tests` profile, so `docker compose up` doesn't start it; it targets the load balancer, `BASE_URL=http://nginx`). Results are pushed to Prometheus via remote write and shown on the Grafana "Load tests" dashboard (http://localhost:3001/d/load-tests).
- Tracing: the apps send OpenTelemetry traces (`config/initializers/opentelemetry.rb`, only enabled when `OTEL_EXPORTER_OTLP_ENDPOINT` is set, as compose does) to Grafana Tempo (`config/tempo/tempo.yml`, query API on http://localhost:3200). Tempo's span metrics (`traces_spanmetrics_*`, with a `service_instance_id` label) and service graph are pushed to Prometheus. Grafana dashboards: "APM" (http://localhost:3001/d/apm, New Relic-style summary built from the span metrics) and "Request traces" (http://localhost:3001/d/traces, recent requests and the full trace of the selected one).
- `config/database.yml` reads `DATABASE_HOST` (set to `postgres` by compose) and `DATABASE_USERNAME` (defaults to `postgres`).

## Checks

- Tests: `docker compose exec app bin/rails test`
- Lint: `docker compose exec app bin/rubocop` (rubocop-rails-omakase)
- Full CI: `bin/ci` (rubocop, bundler-audit, brakeman, tests, seeds)
