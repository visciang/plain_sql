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
  Builds a Fragment with one Identifier.

  Rendering always quotes `name` with the delimiter pair of the Dialect. On Postgres
  `identifier("Users")` renders `"Users"`, which names a different table from unquoted
  `Users`. There is no composite form. Write
  `~q"\#{identifier("public")}.\#{identifier("users")}"` for a qualified name.

  Raises `ArgumentError` for a non-binary and for `""`. `PlainSQL.render/2` raises
  `ArgumentError` when `name` contains a delimiter of the Dialect.
  """
  @spec identifier(String.t()) :: Fragment.t()
  def identifier(name) when is_binary(name) and name != "" do
    %Fragment{parts: [{:identifier, name}]}
  end

  def identifier(other) do
    raise ArgumentError, "identifier/1 expects a non-empty binary, got: #{inspect(other)}"
  end

  @doc """
  Builds a Fragment from SQL text known at runtime.

  The text renders verbatim. Never pass text derived from user input.

  `raw("")` is the Empty Fragment. Raises `ArgumentError` for a non-binary.
  """
  @spec raw(String.t()) :: Fragment.t()
  def raw(""), do: %Fragment{parts: []}
  def raw(text) when is_binary(text), do: %Fragment{parts: [{:text, text}]}

  def raw(other) do
    raise ArgumentError, "raw/1 expects a binary, got: #{inspect(other)}"
  end

  @doc """
  Builds a Fragment with one placeholder per element of `values`.

  Rendering emits `(p1, p2, ..., pn)`. The text works after `IN` and after `NOT IN` and
  as a `VALUES` row. A bare list in `\#{}` binds as one value instead.

  PlainSQL does not count parameters. The Driver reports its parameter limit.

  Raises `ArgumentError` for an empty list. `IN ()` is invalid SQL on every Dialect.
  """
  @spec list([term(), ...]) :: Fragment.t()
  def list([_ | _] = values), do: %Fragment{parts: [{:list, values}]}

  def list(other) do
    raise ArgumentError, "list/1 expects a non-empty list, got: #{inspect(other)}"
  end

  @doc """
  Joins `fragments` with `separator` between them.

  Skips members that are `nil`, `false`, or the Empty Fragment. Renders the Empty
  Fragment when no member remains.

  Raises `ArgumentError` for a member that is not a Fragment, `nil`, or `false`.
  """
  @spec join([Fragment.t() | nil | false], Fragment.t()) :: Fragment.t()
  def join(fragments, %Fragment{parts: separator}) when is_list(fragments) do
    parts =
      fragments
      |> Enum.flat_map(&member_parts/1)
      |> Enum.intersperse(separator)
      |> List.flatten()

    %Fragment{parts: parts}
  end

  defp member_parts(nil), do: []
  defp member_parts(false), do: []
  defp member_parts(%Fragment{parts: []}), do: []
  defp member_parts(%Fragment{parts: parts}), do: [parts]

  defp member_parts(other) do
    raise ArgumentError,
          "join/2 expects a Fragment, nil, or false for each member, got: #{inspect(other)}"
  end

  @doc """
  Joins the predicates in `fragments` with ` AND `.

  Wraps every member in parentheses, also a single member. Skips members that are `nil`,
  `false`, or the Empty Fragment. Renders the Empty Fragment when no member remains.

  Raises `ArgumentError` for a member that is not a Fragment, `nil`, or `false`.
  """
  @spec all([Fragment.t() | nil | false]) :: Fragment.t()
  def all(fragments) when is_list(fragments) do
    fragments
    |> Enum.map(&parenthesize/1)
    |> join(%Fragment{parts: [{:text, " AND "}]})
  end

  @doc """
  Joins the predicates in `fragments` with ` OR `.

  Wraps every member in parentheses, also a single member. Skips members that are `nil`,
  `false`, or the Empty Fragment.

  Raises `ArgumentError` when no member remains. The identity of `OR` is `FALSE` and no
  portable literal for it exists. Raises `ArgumentError` for a member that is not a
  Fragment, `nil`, or `false`.
  """
  @spec any([Fragment.t() | nil | false]) :: Fragment.t()
  def any(fragments) when is_list(fragments) do
    case Enum.map(fragments, &parenthesize/1) |> join(%Fragment{parts: [{:text, " OR "}]}) do
      %Fragment{parts: []} -> raise ArgumentError, "any/1 needs at least one predicate"
      fragment -> fragment
    end
  end

  defp parenthesize(%Fragment{parts: [_ | _] = parts}) do
    %Fragment{parts: [{:text, "("} | parts] ++ [{:text, ")"}]}
  end

  defp parenthesize(other), do: other

  @doc """
  Renders `WHERE ` followed by `fragment`.

  Renders the Empty Fragment when `fragment` is the Empty Fragment.
  """
  @spec where(Fragment.t()) :: Fragment.t()
  def where(%Fragment{parts: []} = empty), do: empty
  def where(%Fragment{parts: parts}), do: %Fragment{parts: [{:text, "WHERE "} | parts]}

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
