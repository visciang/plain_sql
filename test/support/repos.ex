# Ecto repos for the test suite. `start_link/1` takes the connection options.

defmodule PlainSQL.TestSupport.PostgresRepo do
  @moduledoc false
  use Ecto.Repo, otp_app: :plain_sql, adapter: Ecto.Adapters.Postgres
end

defmodule PlainSQL.TestSupport.SQLiteRepo do
  @moduledoc false
  use Ecto.Repo, otp_app: :plain_sql, adapter: Ecto.Adapters.SQLite3
end

defmodule PlainSQL.TestSupport.MySQLRepo do
  @moduledoc false
  # Exports `__adapter__/0` only. No MySQL database runs in the test suite.
  def __adapter__, do: Ecto.Adapters.MyXQL
end

defmodule PlainSQL.TestSupport.MSSQLRepo do
  @moduledoc false
  # Exports `__adapter__/0` only. No MSSQL database runs in the test suite.
  def __adapter__, do: Ecto.Adapters.Tds
end

defmodule PlainSQL.TestSupport.UnknownAdapterRepo do
  @moduledoc false
  def __adapter__, do: Ecto.Adapters.Unknown
end
