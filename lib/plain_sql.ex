defmodule PlainSQL do
  @moduledoc """
  Write SQL as SQL.

  Write `import PlainSQL`. Compose a query with `~q`. A Fragment in `\#{}` splices. Any
  other value in `\#{}` binds. `render/2` turns the Fragment into the SQL string and the
  ordered value list for one Dialect.
  """

  alias PlainSQL.Fragment

  @doc """
  Builds a Fragment from SQL text.

  The text is verbatim. A `%PlainSQL.Fragment{}` in `\#{}` splices its parts at that
  position. Any other value in `\#{}` binds as one `{:binding, value}` part. The sigil never
  converts a value.

  Raises `ArgumentError` at compile time for a sigil modifier and for an empty `\#{}`.
  """
  defmacro sigil_q({:<<>>, _meta, parts}, modifiers) do
    if modifiers != [] do
      raise ArgumentError, "~q accepts no modifier, got: #{modifiers}"
    end

    quoted_parts = Enum.map(parts, &quote_part/1)

    quote do
      %Fragment{parts: List.flatten(unquote(quoted_parts))}
    end
  end

  defp quote_part(""), do: []

  defp quote_part(text) when is_binary(text) do
    quote do: [{:text, unquote(text)}]
  end

  defp quote_part({:"::", _, [{{:., _, [Kernel, :to_string]}, _, [{:__block__, _, []}]}, _]}) do
    raise ArgumentError, "~q does not accept an empty \#{}"
  end

  defp quote_part({:"::", _, [{{:., _, [Kernel, :to_string]}, _, [expr]}, {:binary, _, _}]}) do
    quote do: PlainSQL.__part__(unquote(expr))
  end

  @doc false
  def __part__(%Fragment{parts: parts}), do: parts
  def __part__(value), do: [{:binding, value}]

  @doc """
  Renders `fragment` for `dialect`.

  Returns the SQL string and the params in text order. `dialect` is a module that
  implements `PlainSQL.Dialect`. The Empty Fragment renders `{"", []}`.

  Raises `ArgumentError` when an Identifier contains a delimiter of `dialect`.
  """
  @spec render(Fragment.t(), dialect :: module()) :: {sql :: String.t(), params :: [term()]}
  def render(%Fragment{parts: parts}, dialect) when is_atom(dialect) do
    {sql, params, _next} =
      Enum.reduce(parts, {[], [], 1}, fn
        {:text, text}, {sql, params, n} ->
          {[sql | text], params, n}

        {:binding, value}, {sql, params, n} ->
          {[sql | dialect.placeholder(n)], [value | params], n + 1}

        {:list, values}, {sql, params, n} ->
          count = length(values)
          placeholders = Enum.map_join(n..(n + count - 1)//1, ", ", &dialect.placeholder/1)
          {[sql, "(", placeholders, ")"], Enum.reverse(values, params), n + count}

        {:identifier, name}, {sql, params, n} ->
          {[sql | quote_identifier(name, dialect)], params, n}
      end)

    {IO.iodata_to_binary(sql), Enum.reverse(params)}
  end

  defp quote_identifier(name, dialect) do
    {open, close} = dialect.identifier_delimiters()

    if String.contains?(name, [open, close]) do
      raise ArgumentError,
            "identifier #{inspect(name)} contains a delimiter of #{inspect(dialect)}"
    end

    [open, name, close]
  end
end
