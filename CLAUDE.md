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

- Start: `docker compose up -d` (app on http://localhost:3000, Postgres on host port 5433, so it can run alongside drc-api)
- Run any Rails command: `docker compose exec app bin/rails <cmd>`
- Gems live in the `gems` volume; `bundle install` runs on container start.
- `config/database.yml` reads `DATABASE_HOST` (set to `postgres` by compose) and `DATABASE_USERNAME` (defaults to `postgres`).

## Checks

- Tests: `docker compose exec app bin/rails test`
- Lint: `docker compose exec app bin/rubocop` (rubocop-rails-omakase)
- Full CI: `bin/ci` (rubocop, bundler-audit, brakeman, tests, seeds)
