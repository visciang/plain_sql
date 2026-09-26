PG_CONTAINER ?= plain_sql_postgres
PG_PORT ?= 5433
PG_PASSWORD ?= plain_sql
export PG_URL ?= postgres://postgres:$(PG_PASSWORD)@localhost:$(PG_PORT)/postgres

.PHONY: db-up db-down check-no-deps

db-up:
	docker run --detach --rm --name $(PG_CONTAINER) \
		--env POSTGRES_PASSWORD=$(PG_PASSWORD) \
		--publish $(PG_PORT):5432 \
		postgres:17-alpine
	@until docker exec $(PG_CONTAINER) pg_isready --username postgres >/dev/null 2>&1; do sleep 0.5; done
	@echo "export PG_URL=$(PG_URL)"

db-down:
	docker stop $(PG_CONTAINER)

# Compiles lib/ in a copy of the project with every dep removed.
check-no-deps:
	rm -rf /tmp/plain_sql_no_deps && mkdir -p /tmp/plain_sql_no_deps
	cp -R lib /tmp/plain_sql_no_deps/
	sed -e '/{:db_connection/,/{:ecto_sqlite3/d' mix.exs > /tmp/plain_sql_no_deps/mix.exs
	cd /tmp/plain_sql_no_deps && mix compile --warnings-as-errors
