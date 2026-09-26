# Test doubles for the Drivers that the test suite does not run against a database.
# `myxql` and `tds` are not deps. Each double carries the module name that PlainSQL
# dispatches on. `query/4` returns its arguments so a test observes the call.

defmodule MyXQL.Connection do
  @moduledoc false
  use PlainSQL.TestSupport.StubConnection
end

defmodule MyXQL do
  @moduledoc false
  def query(conn, sql, params, opts), do: {:fake_query, __MODULE__, conn, sql, params, opts}
end

defmodule Tds.Parameter do
  @moduledoc false
  # Mirrors the struct of tds 2.3, lib/tds/parameter.ex.
  defstruct name: "", direction: :input, value: "", type: nil, length: nil
end

defmodule Tds.Protocol do
  @moduledoc false
  use PlainSQL.TestSupport.StubConnection
end

defmodule Tds do
  @moduledoc false
  def query(conn, sql, params, opts), do: {:fake_query, __MODULE__, conn, sql, params, opts}
end
