defmodule PlainSQL.Dialect.Postgres do
  @moduledoc "The Dialect for PostgreSQL. Placeholders are `$1`, `$2`, ... Identifiers use `\"`."

  @behaviour PlainSQL.Dialect

  @impl true
  def placeholder(position), do: "$#{position}"

  @impl true
  def identifier_delimiters, do: {"\"", "\""}
end
