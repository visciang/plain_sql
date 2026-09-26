defmodule PlainSQL.Dialect.MSSQL do
  @moduledoc "The Dialect for Microsoft SQL Server. Placeholders are `@1`, `@2`, ... Identifiers use `[` and `]`."

  @behaviour PlainSQL.Dialect

  @impl true
  def placeholder(position), do: "@#{position}"

  @impl true
  def identifier_delimiters, do: {"[", "]"}
end
