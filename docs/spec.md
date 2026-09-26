# PlainSQL design spec

Status: ready for implementation. Assembled 2026-09-26 from the resolved tickets of `.scratch/plain_sql-spec/`. Terms follow `/CONTEXT.md`.

## 1. Purpose and portability

PlainSQL is an Elixir library for writing SQL as SQL. The developer writes SQL text in a sigil. Each `#{}` in the sigil becomes a Binding or a Splice. The developer composes Fragments with a small set of helpers. Rendering turns one Fragment into the SQL string and the ordered value list that a Driver accepts, for one Dialect.

PlainSQL does not parse SQL. PlainSQL does not contain a Driver.

### Portability statement

This text is the README statement.

> PlainSQL renders one Fragment for one Dialect at a time. A Dialect decides the placeholder style and the identifier quoting. A Dialect does not change the SQL text. PlainSQL does not check that the SQL text is valid for the target database. The developer owns the SQL text.

### Divergence list

A Dialect decides two things. The list is closed.

1. The placeholder text for the Binding at position N.
2. The identifier delimiter pair.

A Dialect has no other effect on the rendered text. Rendering never inspects a bound value. A value the target database cannot accept passes through to the Driver. The Driver raises on execute.

## 2. Public API

The developer writes `import PlainSQL`. Every public function lives in `PlainSQL`.

### 2.1 Fragment

`PlainSQL.Fragment` holds the struct and the part type only. It has no functions.

```elixir
defmodule PlainSQL.Fragment do
  @type part ::
          {:text, String.t()}
          | {:binding, term()}
          | {:list, [term()]}
          | {:identifier, String.t()}

  @type t :: %__MODULE__{parts: [part()]}

  defstruct parts: []
end
```

- A Fragment is an ordered list of parts.
- A Fragment stores no placeholder numbers. Rendering assigns placeholders in part order.
- A Fragment holds no nested Fragment. Splicing flattens the inner parts into the outer list.
- The Empty Fragment is `%PlainSQL.Fragment{parts: []}`. `~q""` and `raw("")` produce it. There is no `empty/0` function.

### 2.2 Sigil `~q`

`sigil_q/2` is a macro in `PlainSQL`.

Text rules:

- The sigil text is verbatim. The only transform is the delimiter escape (`\"` becomes `"`). `\n` stays two characters.
- The heredoc form `~q"""` is the documented form for multi-line SQL. The heredoc form strips the indentation.
- Alternate delimiters (`~q|...|`) work.
- The macro drops `{:text, ""}` parts.

Binding rule for `#{}`:

- The macro replaces each `#{expr}` with a runtime check on the value of `expr`.
- A `%PlainSQL.Fragment{}` value splices. Its parts take the position of the `#{}`.
- Any other value binds as one `{:binding, value}` part. This includes a string, a list, a map, `%Date{}`, and `%Decimal{}`. The sigil never converts a value. The Driver decides the encoding.
- `nil` binds. The Driver receives `NULL`. `nil` is never the Empty Fragment.
- A plain string in `#{}` never splices as SQL text. Use `raw/1` for runtime SQL text.
- There is no compile-time rule by AST shape. A Fragment in a variable and a Fragment written inline produce identical parts.

Modifiers: none in v1. See section 4.

### 2.3 Splicing rules

1. Splicing is verbatim. It adds no whitespace and normalises no text.
2. Binding order is text order. Rendering numbers Bindings in the order of the rendered text.
3. A Fragment spliced twice contributes its Bindings twice. Each occurrence gets its own placeholder.
4. Splicing the Empty Fragment adds no text and no Bindings.

### 2.4 Helpers

Boundary rule: a helper takes Fragments or values, emits text at its own Splicing position, and never reads the text around it.

Naming rule: a helper that emits a SQL keyword is named after that keyword. `and_/1` and `or_/1` carry a trailing underscore because `and` and `or` are Elixir operators.

Skip rule: a helper argument that is `nil`, `false`, or the Empty Fragment is absent. A list helper (`join/2`, `and_/1`, `or_/1`, `group_by/1`, `order_by/1`, `set/1`) skips an absent member. A unary helper (`where/1`, `having/1`) treats an absent argument as the Empty Fragment. `empty?/1` returns `true` for an absent argument.

Argument rule: every helper raises `ArgumentError` at the call for an argument or a member that is not a Fragment, `nil`, or `false`. A list helper raises `ArgumentError` at the call for a `fragments` argument that is not a list.

`empty?(fragment)`

- Returns `true` for the Empty Fragment, `nil`, and `false`. Returns `false` for every other Fragment.

`join(fragments, separator)`

- Takes a list of Fragments and a separator Fragment. Raises `ArgumentError` at the call for a separator that is not a Fragment.
- Renders the remaining members in order with the separator between them.
- Renders the Empty Fragment when no member remains.
- `join/2` is the primitive under `and_/1`, `or_/1`, `group_by/1`, `order_by/1`, and `set/1`.

`and_(fragments)`

- Joins the remaining members with ` AND `. Wraps every member in parentheses, also a single member.
- Renders the Empty Fragment when no member remains.

`or_(fragments)`

- Joins the remaining members with ` OR `. Wraps every member in parentheses, also a single member.
- Raises `ArgumentError` when no member remains. The identity of `OR` is `FALSE`. MSSQL has no boolean literal. No portable literal exists.

`where(fragment)`

- Takes one Fragment. Renders `WHERE ` followed by the Fragment.
- Renders the Empty Fragment when the argument is absent.

`having(fragment)`

- Same as `where/1` with `HAVING `.

`group_by(fragments)`

- Takes a list of Fragments. Renders `GROUP BY ` followed by the remaining members joined with `, `. No parentheses around a member.
- Renders the Empty Fragment when no member remains.

`order_by(fragments)`

- Same as `group_by/1` with `ORDER BY `.

`set(fragments)`

- Same as `group_by/1` with `SET `.
- Raises `ArgumentError` when no member remains. `UPDATE` without `SET` is invalid SQL on every Dialect.
- Takes Fragments, not a map. Section 6 keeps the `UPDATE SET` builder from a map out of scope.

No `limit/1`, `offset/1`, or `returning/1`. `LIMIT` and `OFFSET` are not portable to MSSQL. `RETURNING` is not portable to MySQL and MSSQL. The developer writes them as `~q` text.

No negation helper. The developer writes `~q"NOT (#{pred})"`.

`list(values)`

- Takes a list of values. Produces one `{:list, values}` part.
- Raises `ArgumentError` at the call for an empty list. `IN ()` is invalid SQL on every Dialect.
- Rendering emits `(p1, p2, ..., pn)`: one placeholder per element, separator `, `, parentheses included. The text works after `IN` and after `NOT IN`.
- A bare list in `#{}` stays one `{:binding, list}` part. The Driver receives one value. The developer writes `id = ANY(#{ids})` for the Postgres array form.
- PlainSQL does not count parameters. The Driver reports its parameter limit.

`identifier(name)`

- Takes a binary. Raises `ArgumentError` at the call for any other value and for `""`.
- Returns a Fragment with one `{:identifier, name}` part.
- Rendering always quotes the name with the pair from `identifier_delimiters/0`. `identifier("Users")` renders `"Users"` on Postgres. On Postgres this names a different table from unquoted `Users`.
- Rendering raises `ArgumentError` when the name contains the open or the close delimiter of the Dialect.
- No composite form. `identifier("public.users")` renders one quoted name. The developer writes `#{identifier("public")}.#{identifier("users")}`.

`raw(text)`

- Takes a binary. Raises `ArgumentError` at the call for any other value.
- Returns a Fragment with one `{:text, text}` part. `raw("")` is the Empty Fragment.
- Serves SQL text not known at compile time, for example `File.read!("report.sql")`.
- `@doc` warning: "The text renders verbatim. Never pass text derived from user input."

Idioms:

```elixir
conds = and_([~q"status = #{status}", ids != [] && ~q"id IN #{list(ids)}"])
~q"SELECT * FROM orders #{where(conds)}"

cols = join(Enum.map(names, &identifier/1), ~q", ")
~q"INSERT INTO #{identifier(table)} (#{cols}) VALUES #{list(values)}"

rows = join(Enum.map(values_per_row, &list/1), ~q", ")
~q"INSERT INTO t (a, b) VALUES #{rows}"

order = order_by([~q"created_at DESC", by_name && ~q"name"])
~q"SELECT * FROM orders #{where(ids != [] && ~q"id IN #{list(ids)}")} #{order}"

~q"UPDATE orders #{set([~q"status = #{status}", note && ~q"note = #{note}"])} WHERE id = #{id}"
```

### 2.5 Rendering

```elixir
@spec render(PlainSQL.Fragment.t(), dialect :: module()) :: {sql :: String.t(), params :: [term()]}
```

- The Dialect module is explicit on every call. There is no `render/1`, no application default, no process default, and no atom shorthand.
- `sql` is a binary.
- `params` holds one entry per `{:binding, value}` part and one entry per element of a `{:list, values}` part, in text order.
- The Empty Fragment renders `{"", []}`.
- `render/2` raises `ArgumentError` for an identifier with an embedded delimiter. There is no `{:ok, _} | {:error, _}` form.
- `render/2` does not check that the Dialect module implements the behaviour. A missing callback fails with `UndefinedFunctionError`.

Part rendering:

| Part | Rendered text | Params |
|---|---|---|
| `{:text, t}` | `t` | none |
| `{:binding, v}` | `dialect.placeholder(n)` | `v` |
| `{:list, [v1, ..., vk]}` | `(` + placeholders `n..n+k-1` joined by `, ` + `)` | `v1, ..., vk` |
| `{:identifier, name}` | `open <> name <> close` from `dialect.identifier_delimiters()` | none |

`n` is the position of the next Binding, counted from 1 in text order.

### 2.6 Errors

Every error PlainSQL raises is an `ArgumentError`. Message text is not fixed by this spec.

| Case | When |
|---|---|
| Any modifier on `~q` | compile time |
| Empty `#{}` in `~q` | compile time |
| `or_/1` or `set/1` with no remaining member | call |
| `list/1` with an empty list | call |
| `identifier/1` with a non-binary or `""` | call |
| `raw/1` with a non-binary | call |
| Helper argument or member that is not a Fragment, `nil`, or `false` | call |
| List helper `fragments` argument that is not a list | call |
| Identifier name contains a delimiter of the Dialect | `render/2` |
| `dialect/1` cannot infer a Dialect | `dialect/1`, `query/3` |

## 3. Dialect contract

### 3.1 Behaviour

```elixir
defmodule PlainSQL.Dialect do
  @callback placeholder(position :: pos_integer()) :: String.t()
  @callback identifier_delimiters() :: {open :: String.t(), close :: String.t()}
end
```

The callback list is closed. It follows the divergence list of section 1. There is no `use PlainSQL.Dialect` macro and no registration step.

Two Rendering rules are core, not callbacks. They are the `{:list, values}` expansion and the embedded-delimiter check.

### 3.2 Shipped Dialect modules

| Module | `placeholder(n)` | `identifier_delimiters()` |
|---|---|---|
| `PlainSQL.Dialect.Postgres` | `"$#{n}"` | `{"\"", "\""}` |
| `PlainSQL.Dialect.SQLite` | `"?"` | `{"\"", "\""}` |
| `PlainSQL.Dialect.MySQL` | `"?"` | ``{"`", "`"}`` |
| `PlainSQL.Dialect.MSSQL` | `"@#{n}"` | `{"[", "]"}` |

Postgres and SQLite are the reference Dialects. MySQL and MSSQL tests are Rendering-only. No MySQL or MSSQL database runs in the test suite.

### 3.3 Adding a Dialect

A new Dialect is one module. The `PlainSQL.Dialect` moduledoc carries this skeleton.

```elixir
defmodule PlainSQL.Dialect.MSSQL do
  @behaviour PlainSQL.Dialect

  @impl true
  def placeholder(position), do: "@#{position}"

  @impl true
  def identifier_delimiters, do: {"[", "]"}
end
```

A Dialect outside the shipped four is reachable through `render/2` only. `dialect/1` and `query/3` do not infer it.

## 4. Compile-time checks

The `~q` macro performs two checks. Both raise `ArgumentError` from the macro. The compiler reports the raise with file and line.

1. Any sigil modifier.
2. An empty `#{}`. It is never a valid Binding.

No other check:

- No check on a string literal in `#{}`. It binds as a value at runtime.
- No check on the SQL text. The macro does not read the text for quote balance or for a `#{}` inside quotes. A Fragment is partial by design.
- No check on a Fragment with no `#{}`. It is a plain Fragment.
- No check that needs the position of a `#{}` in the SQL grammar.
- No configuration and no strict mode.

Documentation requirement: the README documents the `'#{name}'` mistake. A `#{}` inside a quoted literal renders a placeholder inside the quotes. The database receives a string literal, not a Binding.

## 5. Execution seam

`PlainSQL` ships `dialect/1` and `query/3` in the core package. There is no `query!/3`, no `stream`, no `prepare`, and no result mapping.

```elixir
@spec dialect(conn_or_repo :: DBConnection.conn() | module()) :: module()
@spec query(conn_or_repo :: DBConnection.conn() | module(), PlainSQL.Fragment.t(), opts :: keyword()) :: term()
```

### 5.1 `dialect/1`

Returns one of the four shipped Dialect modules for a live connection or an Ecto repo module. It is public. A caller uses it to reach Driver functions that `query/3` does not cover.

Dispatch rule: an atom that exports `__adapter__/0` is a repo. Every other value is a `DBConnection.conn()`: a pool pid, a registered name, a `{:via, _, _}` tuple, or the `%DBConnection{}` handle inside `run/3` and `transaction/3`. A repo pid is not accepted on the repo path.

Inference table. PlainSQL owns it. It is closed.

| Source | Call | Result | Dialect | Driver module |
|---|---|---|---|---|
| `DBConnection.conn()` | `DBConnection.connection_module/1` | `Postgrex.Protocol` | `PlainSQL.Dialect.Postgres` | `Postgrex` |
| | | `Exqlite.Connection` | `PlainSQL.Dialect.SQLite` | `Exqlite` |
| | | `MyXQL.Connection` | `PlainSQL.Dialect.MySQL` | `MyXQL` |
| | | `Tds.Protocol` | `PlainSQL.Dialect.MSSQL` | `Tds` |
| repo module | `repo.__adapter__/0` | `Ecto.Adapters.Postgres` | `PlainSQL.Dialect.Postgres` | the repo |
| | | `Ecto.Adapters.SQLite3` | `PlainSQL.Dialect.SQLite` | the repo |
| | | `Ecto.Adapters.MyXQL` | `PlainSQL.Dialect.MySQL` | the repo |
| | | `Ecto.Adapters.Tds` | `PlainSQL.Dialect.MSSQL` | the repo |

Failure: `dialect/1` raises `ArgumentError` when `DBConnection.connection_module/1` returns `:error` or returns a module with no table row. The message names the value. There is no override option.

### 5.2 `query/3`

`query(conn_or_repo, fragment, opts \\ [])`:

1. `dialect = dialect(conn_or_repo)`. This raises before Rendering on inference failure.
2. `{sql, params} = render(fragment, dialect)`.
3. Connection path: `Driver.query(conn, sql, params, opts)` with the Driver module from the table row.
4. Repo path: `repo.query(sql, params, opts)`, the function `use Ecto.Adapters.SQL` injects. It honours `put_dynamic_repo/1`.

The return value is the Driver result untouched. `opts` reaches the Driver unchanged. PlainSQL reads no key from `opts`.

The Empty Fragment reaches the Driver as an empty statement. PlainSQL does not check it.

Tds param shape: the Tds row wraps each rendered param as `struct(Tds.Parameter, name: "@#{n}", value: v)` in list order before the `Tds.query/4` call. This is the one Driver-specific clause in `query/3`.

### 5.3 Packaging

One package. `db_connection` and `ecto_sql` are `optional: true` deps. Driver modules appear as atoms in the table. Compilation without the optional deps present must be warning-free. The mechanism (`Code.ensure_loaded?/1` guard or `apply/3`) is the implementer's choice.

## 6. Out of scope

- Connection pooling and wire protocols. Drivers own them.
- Transactions and streaming. Drivers and Ecto own them.
- Result-row mapping to structs. Every Driver has a different result shape.
- Compile-time schema validation (`sql.lock` style).
- `mix format` plugin for SQL text.
- Migrations.
- SQL transpiling: rewriting `LIMIT`/`TOP`, `RETURNING`, upsert, boolean literals, or any SQL text between Dialects. A Dialect changes how values and identifiers are bound, never what the SQL says.
- Forking or contributing to elixir-dbvisor/sql.
- `INSERT` and `UPDATE SET` builders from a map, and dynamic `ORDER BY` builders. Ruled out by the boundary rule of section 2.4.
- Dialect-specific Fragments (a `dialect:` tag that makes Rendering under another Dialect raise). Ruled out by the portability statement.
- A `~q` Fragment inside an Ecto `fragment/1`. It needs Ecto's `?` placeholder and a compile-time literal. That is macro work against `Ecto.Query`, not Rendering.
- Named bindings (`:id` style). `~q` binds by expression position. A named form is a new effort.

## 7. Open items

These items are not fixed by this spec. The implementation effort decides them.

- The message text of each `ArgumentError` in section 2.6.
- The test strategy for Rendering per Dialect.

## Appendix: traceability

| Public symbol | Ticket |
|---|---|
| `PlainSQL.sigil_q/2` | [03](../.scratch/plain_sql-spec/issues/03-sigil-and-binding-rule.md), [08](../.scratch/plain_sql-spec/issues/08-compile-time-checks.md) |
| `PlainSQL.Fragment` struct and `part` type | [02](../.scratch/plain_sql-spec/issues/02-composition-model.md), [05](../.scratch/plain_sql-spec/issues/05-dialect-contract.md), [09](../.scratch/plain_sql-spec/issues/09-identifier-and-raw.md) |
| `PlainSQL.and_/1`, `or_/1`, `where/1`, `list/1` | [02](../.scratch/plain_sql-spec/issues/02-composition-model.md) |
| `PlainSQL.empty?/1`, `having/1`, `group_by/1`, `order_by/1`, `set/1`, skip rule on unary helpers | grilling 2026-09-26, [implementation ticket 08](../.scratch/plain_sql-implementation/issues/08-compose-optional-clauses.md) |
| `PlainSQL.join/2`, `identifier/1`, `raw/1` | [09](../.scratch/plain_sql-spec/issues/09-identifier-and-raw.md) |
| `PlainSQL.render/2` | [05](../.scratch/plain_sql-spec/issues/05-dialect-contract.md) |
| `PlainSQL.Dialect` behaviour and the four modules | [04](../.scratch/plain_sql-spec/issues/04-portability-statement.md), [05](../.scratch/plain_sql-spec/issues/05-dialect-contract.md) |
| `PlainSQL.dialect/1`, `query/3` | [06](../.scratch/plain_sql-spec/issues/06-dialect-inference.md), [07](../.scratch/plain_sql-spec/issues/07-execution-seam.md) |
| Portability statement | [04](../.scratch/plain_sql-spec/issues/04-portability-statement.md) |
