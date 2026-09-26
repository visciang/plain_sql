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
  `identifier("Users")` renders `"Users"`. That names a different table from unquoted
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
  as a `VALUES` row. A bare list in `\#{}` binds as one value.

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

  Raises `ArgumentError` for a member that is not a Fragment, `nil`, or `false`. Raises
  `ArgumentError` for a separator that is not a Fragment.
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

  def join(fragments, separator) when is_list(fragments) do
    raise ArgumentError, "join/2 expects a Fragment separator, got: #{inspect(separator)}"
  end

  defp member_parts(nil), do: []
  defp member_parts(false), do: []
  defp member_parts(%Fragment{parts: []}), do: []
  defp member_parts(%Fragment{parts: parts}), do: [parts]

  defp member_parts(other) do
    raise ArgumentError, "expected a Fragment, nil, or false, got: #{inspect(other)}"
  end

  @doc """
  Joins the predicates in `fragments` with ` AND `.

  Wraps every member in parentheses, also a single member. Skips members that are `nil`,
  `false`, or the Empty Fragment. Renders the Empty Fragment when no member remains.

  Raises `ArgumentError` for a member that is not a Fragment, `nil`, or `false`.
  """
  @spec all([Fragment.t() | nil | false]) :: Fragment.t()
  def all(fragments) when is_list(fragments), do: join_predicates(fragments, " AND ")

  @doc """
  Joins the predicates in `fragments` with ` OR `.

  Wraps every member in parentheses, also a single member. Skips members that are `nil`,
  `false`, or the Empty Fragment.

  Raises `ArgumentError` when no member remains. The identity of `OR` is `FALSE`. No
  portable literal for `FALSE` exists. Raises `ArgumentError` for a member that is not a
  Fragment, `nil`, or `false`.
  """
  @spec any([Fragment.t() | nil | false]) :: Fragment.t()
  def any(fragments) when is_list(fragments) do
    case join_predicates(fragments, " OR ") do
      %Fragment{parts: []} -> raise ArgumentError, "any/1 needs at least one predicate"
      fragment -> fragment
    end
  end

  defp join_predicates(fragments, separator) do
    fragments
    |> Enum.map(&parenthesize/1)
    |> join(%Fragment{parts: [{:text, separator}]})
  end

  defp parenthesize(%Fragment{parts: [_ | _] = parts}) do
    %Fragment{parts: [{:text, "("} | parts] ++ [{:text, ")"}]}
  end

  defp parenthesize(other), do: other

  @doc """
  Renders `WHERE ` followed by `fragment`.

  Renders the Empty Fragment when `fragment` is the Empty Fragment, `nil`, or `false`.

  Raises `ArgumentError` for an argument that is not a Fragment, `nil`, or `false`.
  """
  @spec where(Fragment.t() | nil | false) :: Fragment.t()
  def where(fragment), do: clause("WHERE ", fragment)

  @doc """
  Renders `HAVING ` followed by `fragment`.

  Renders the Empty Fragment when `fragment` is the Empty Fragment, `nil`, or `false`.

  Raises `ArgumentError` for an argument that is not a Fragment, `nil`, or `false`.
  """
  @spec having(Fragment.t() | nil | false) :: Fragment.t()
  def having(fragment), do: clause("HAVING ", fragment)

  @doc """
  Renders `GROUP BY ` followed by the members of `fragments` joined with `, `.

  Skips members that are `nil`, `false`, or the Empty Fragment. Renders the Empty
  Fragment when no member remains. No parentheses around a member.

  Raises `ArgumentError` for a member that is not a Fragment, `nil`, or `false`.
  """
  @spec group_by([Fragment.t() | nil | false]) :: Fragment.t()
  def group_by(fragments) when is_list(fragments), do: clause("GROUP BY ", comma_list(fragments))

  @doc """
  Renders `ORDER BY ` followed by the members of `fragments` joined with `, `.

  Skips members that are `nil`, `false`, or the Empty Fragment. Renders the Empty
  Fragment when no member remains. No parentheses around a member.

  Raises `ArgumentError` for a member that is not a Fragment, `nil`, or `false`.
  """
  @spec order_by([Fragment.t() | nil | false]) :: Fragment.t()
  def order_by(fragments) when is_list(fragments), do: clause("ORDER BY ", comma_list(fragments))

  @doc """
  Renders `SET ` followed by the members of `fragments` joined with `, `.

  Skips members that are `nil`, `false`, or the Empty Fragment. No parentheses around a
  member. Takes Fragments, not a map.

  Raises `ArgumentError` when no member remains. `UPDATE` without `SET` is invalid SQL on
  every Dialect. Raises `ArgumentError` for a member that is not a Fragment, `nil`, or
  `false`.
  """
  @spec set([Fragment.t() | nil | false]) :: Fragment.t()
  def set(fragments) when is_list(fragments) do
    case comma_list(fragments) do
      %Fragment{parts: []} -> raise ArgumentError, "set/1 needs at least one assignment"
      members -> clause("SET ", members)
    end
  end

  defp comma_list(fragments), do: join(fragments, %Fragment{parts: [{:text, ", "}]})

  @doc """
  Returns `true` for the Empty Fragment, `nil`, and `false`.

  Raises `ArgumentError` for an argument that is not a Fragment, `nil`, or `false`.
  """
  @spec empty?(Fragment.t() | nil | false) :: boolean()
  def empty?(fragment), do: member_parts(fragment) == []

  defp clause(keyword, fragment) do
    case member_parts(fragment) do
      [] -> %Fragment{parts: []}
      [parts] -> %Fragment{parts: [{:text, keyword} | parts]}
    end
  end

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

  # Connection module of a DBConnection pool => {Dialect, Driver module}.
  @connection_drivers %{
    Postgrex.Protocol => {PlainSQL.Dialect.Postgres, Postgrex},
    Exqlite.Connection => {PlainSQL.Dialect.SQLite, Exqlite},
    MyXQL.Connection => {PlainSQL.Dialect.MySQL, MyXQL},
    Tds.Protocol => {PlainSQL.Dialect.MSSQL, Tds}
  }

  # Ecto adapter of a repo module => Dialect.
  @adapter_dialects %{
    Ecto.Adapters.Postgres => PlainSQL.Dialect.Postgres,
    Ecto.Adapters.SQLite3 => PlainSQL.Dialect.SQLite,
    Ecto.Adapters.MyXQL => PlainSQL.Dialect.MySQL,
    Ecto.Adapters.Tds => PlainSQL.Dialect.MSSQL
  }

  @doc """
  Returns the shipped Dialect module for a live connection or an Ecto repo module.

  An atom that exports `__adapter__/0` is a repo. Every other value is a
  `DBConnection.conn()`: a pool pid, a registered name, a `{:via, _, _}` tuple, or the
  handle inside `DBConnection.run/3` and `DBConnection.transaction/3`. A repo pid is not a
  repo. The inference table is closed:

  | Connection module | Ecto adapter | Dialect |
  |---|---|---|
  | `Postgrex.Protocol` | `Ecto.Adapters.Postgres` | `PlainSQL.Dialect.Postgres` |
  | `Exqlite.Connection` | `Ecto.Adapters.SQLite3` | `PlainSQL.Dialect.SQLite` |
  | `MyXQL.Connection` | `Ecto.Adapters.MyXQL` | `PlainSQL.Dialect.MySQL` |
  | `Tds.Protocol` | `Ecto.Adapters.Tds` | `PlainSQL.Dialect.MSSQL` |

  Raises `ArgumentError` when `conn_or_repo` is not a pool or when its connection module
  or adapter has no table row.
  """
  @spec dialect(conn_or_repo :: DBConnection.conn() | module()) :: module()
  def dialect(conn_or_repo) do
    {dialect, _execute} = target(conn_or_repo)
    dialect
  end

  @doc """
  Renders `fragment` for the Dialect of `conn_or_repo` and executes it.

  A connection goes to `Driver.query/4`. A repo goes to `repo.query/3`. The repo path
  honours `put_dynamic_repo/1`. Returns the result untouched. `opts` reaches the call
  unchanged. Raises `ArgumentError` before Rendering when `dialect/1` cannot infer a
  Dialect.

  On the Tds path each param reaches `Tds.query/4` as a `Tds.Parameter` named after its
  placeholder.
  """
  @spec query(conn_or_repo :: DBConnection.conn() | module(), Fragment.t(), opts :: keyword()) ::
          term()
  def query(conn_or_repo, %Fragment{} = fragment, opts \\ []) do
    {dialect, execute} = target(conn_or_repo)
    {sql, params} = render(fragment, dialect)
    execute.(sql, params, opts)
  end

  defp target(conn_or_repo) do
    if repo?(conn_or_repo), do: repo_target(conn_or_repo), else: connection_target(conn_or_repo)
  end

  defp repo?(atom) when is_atom(atom),
    do: Code.ensure_loaded?(atom) and function_exported?(atom, :__adapter__, 0)

  defp repo?(_other), do: false

  defp repo_target(repo) do
    adapter = repo.__adapter__()

    dialect =
      Map.get(@adapter_dialects, adapter) ||
        raise ArgumentError, "no Dialect for Ecto adapter #{inspect(adapter)}"

    {dialect, &repo.query(&1, &2, &3)}
  end

  # `apply/3` keeps the compile warning-free when `db_connection` is absent.
  defp connection_target(conn) do
    case apply(DBConnection, :connection_module, [conn]) do
      {:ok, module} ->
        {dialect, driver} =
          Map.get(@connection_drivers, module) ||
            raise ArgumentError, "no Dialect for connection module #{inspect(module)}"

        {dialect, &apply(driver, :query, [conn, &1, driver_params(driver, &2), &3])}

      :error ->
        raise ArgumentError, "#{inspect(conn)} is not a DBConnection pool"
    end
  end

  defp driver_params(Tds, params) do
    Enum.with_index(params, fn value, index ->
      struct(Tds.Parameter, name: "@#{index + 1}", value: value)
    end)
  end

  defp driver_params(_driver, params), do: params
end
