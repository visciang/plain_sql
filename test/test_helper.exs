if System.get_env("PG_URL") == nil do
  IO.puts("PG_URL is not set: skipping the live Postgres tests. Run `make db-up` to start one.")
  ExUnit.configure(exclude: [:live_postgres])
end

ExUnit.start()
