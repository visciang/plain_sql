PG_CONTAINER ?= plain_sql_postgres
PG_PORT ?= 5433
PG_PASSWORD ?= plain_sql
export PG_URL ?= postgres://postgres:$(PG_PASSWORD)@localhost:$(PG_PORT)/postgres

.PHONY: db-up db-down test

db-up:
	docker run --detach --rm --name $(PG_CONTAINER) \
		--env POSTGRES_PASSWORD=$(PG_PASSWORD) \
		--publish $(PG_PORT):5432 \
		postgres:17-alpine
	@until docker exec $(PG_CONTAINER) pg_isready --username postgres >/dev/null 2>&1; do sleep 0.5; done
	@echo "export PG_URL=$(PG_URL)"

db-down:
	docker stop $(PG_CONTAINER)

test:
	mix test
