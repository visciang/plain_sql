defmodule PlainSQL.Fragment do
  @moduledoc """
  A piece of SQL text together with the values bound inside it.

  A Fragment is an ordered list of parts. Rendering assigns placeholders in part order.
  A Fragment holds no nested Fragment. Splicing flattens the inner parts into the outer list.
  The Empty Fragment is `%PlainSQL.Fragment{parts: []}`.

  ## Inspect form

  `inspect/2` shows the SQL text and the values in text order.
  `~q"SELECT * FROM orders WHERE status = \#{"open"}"` shows as:

      #PlainSQL.Fragment<"SELECT * FROM orders WHERE status = ?", ["open"]>

  - A Binding shows as `?`.
  - A list part shows as `(?, ?, ...)`, with one `?` for each element.
  - An Identifier shows inside double quotes.
  - The text never contains a value.
  - The caller's inspect options apply to the values. The text shows in full.

  Inspecting is not Rendering. The inspect form uses no Dialect.
  """

  @typedoc """
  One part of a Fragment.

  - `{:text, t}` renders `t` verbatim.
  - `{:binding, v}` renders one placeholder and adds `v` to the params.
  - `{:list, values}` renders one placeholder per element inside parentheses.
  - `{:identifier, name}` renders `name` inside the delimiter pair of the Dialect.
  """
  @type part ::
          {:text, String.t()}
          | {:binding, term()}
          | {:list, [term()]}
          | {:identifier, String.t()}

  @type t :: %__MODULE__{parts: [part()]}

  defstruct parts: []

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%PlainSQL.Fragment{parts: parts}, opts) do
      {sql, params} =
        Enum.reduce(parts, {[], []}, fn
          {:text, text}, {sql, params} ->
            {[sql | text], params}

          {:binding, value}, {sql, params} ->
            {[sql, "?"], [value | params]}

          {:list, values}, {sql, params} ->
            {[sql, "(", Enum.map_join(values, ", ", fn _ -> "?" end), ")"],
             Enum.reverse(values, params)}

          {:identifier, name}, {sql, params} ->
            {[sql, ?", name, ?"], params}
        end)

      concat([
        "#PlainSQL.Fragment<",
        to_doc(IO.iodata_to_binary(sql), %{opts | printable_limit: :infinity}),
        ", ",
        to_doc(Enum.reverse(params), opts),
        ">"
      ])
    end
  end
end
