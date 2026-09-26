defmodule PlainSQL.Dialect.MySQL do
  @moduledoc "The Dialect for MySQL. Every placeholder is `?`. Identifiers use `` ` ``."

  @behaviour PlainSQL.Dialect

  @impl true
  def placeholder(_position), do: "?"

  @impl true
  def identifier_delimiters, do: {"`", "`"}
end
