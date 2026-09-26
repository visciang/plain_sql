defmodule PlainSQL.Dialect.SQLite do
  @moduledoc "The Dialect for SQLite. Every placeholder is `?`. Identifiers use `\"`."

  @behaviour PlainSQL.Dialect

  @impl true
  def placeholder(_position), do: "?"

  @impl true
  def identifier_delimiters, do: {"\"", "\""}
end
