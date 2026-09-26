defmodule PlainSQL.TestSupport.LiveDB do
  @moduledoc false

  @doc "Starts a Postgrex pool from `PG_URL`."
  def start_postgrex(opts \\ []) do
    Postgrex.start_link(postgres_opts() ++ opts)
  end

  @doc "Postgrex connection options parsed from `PG_URL`."
  def postgres_opts do
    uri = URI.parse(System.fetch_env!("PG_URL"))
    [username, password] = String.split(uri.userinfo, ":", parts: 2)

    [
      hostname: uri.host,
      port: uri.port,
      username: username,
      password: password,
      database: String.trim_leading(uri.path, "/")
    ]
  end

  @doc "Starts an Exqlite pool on an in-memory database."
  def start_exqlite(opts \\ []) do
    Exqlite.start_link([database: ":memory:", pool_size: 1] ++ opts)
  end
end
