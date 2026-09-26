defmodule PlainSQL.Dialect do
  @moduledoc """
  The Rendering rules for one SQL variant.

  A Dialect decides two things:

  1. The placeholder text for the Binding at position N.
  2. The identifier delimiter pair.

  A Dialect does not change the SQL text. A new Dialect is one module:

      defmodule PlainSQL.Dialect.MSSQL do
        @behaviour PlainSQL.Dialect

        @impl true
        def placeholder(position), do: "@\#{position}"

        @impl true
        def identifier_delimiters, do: {"[", "]"}
      end

  Pass the module to `PlainSQL.render/2`.
  """

  @doc "Returns the placeholder text for the Binding at `position`, counted from 1."
  @callback placeholder(position :: pos_integer()) :: String.t()

  @doc "Returns the pair that Rendering puts around an Identifier."
  @callback identifier_delimiters() :: {open :: String.t(), close :: String.t()}
end
