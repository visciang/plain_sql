# PlainSQL

An Elixir library for writing SQL as SQL.

The developer writes the SQL text and puts each value in `#{}`.

PlainSQL keeps the values out of the text, renders one placeholder per value in the style of the target database, and returns the SQL string with the ordered value list.

PlainSQL does not parse SQL.
PlainSQL does not send queries to a database on its own.

## Installation

The package is not on Hex. Add the Git dependency to `mix.exs`:

```elixir
def deps do
  [
    {:plain_sql, git: "git@github.com:visciang/plain_sql.git", tag: "v0.1.0"}
  ]
end
```

## Usage

Write the SQL in the `~q` sigil. Put each value in `#{}`. Call `render/2` with the module for the target database.

```elixir
import PlainSQL

status = "open"
query = ~q"SELECT * FROM orders WHERE status = #{status} AND total > #{10}"

render(query, PlainSQL.Dialect.Postgres)
#=> {"SELECT * FROM orders WHERE status = $1 AND total > $2", ["open", 10]}

render(query, PlainSQL.Dialect.SQLite)
#=> {"SELECT * FROM orders WHERE status = ? AND total > ?", ["open", 10]}
```

`import PlainSQL` brings `list/1`, `where/1`, `set/1`, `join/2`, and `raw/1` into the module. A module that defines and calls a local function with one of these names fails to compile. Write `import PlainSQL, except: [list: 1]` and call `PlainSQL.list/1` by its full name.

Four terms describe this example:

- A **Fragment** is a piece of SQL text together with the values bound inside it. `~q` builds a `%PlainSQL.Fragment{}`. A complete query is a Fragment.
- A **Binding** is a value placed in `#{}`. `render/2` emits a placeholder for it, never its text. The sigil never converts a value.
- A **Dialect** is the rendering rules for one SQL variant. It decides the placeholder style: `$1` for Postgres, `?` for SQLite. The [Portability](#portability) section lists the shipped Dialects.
- A **Driver** is the library that sends the rendered query to the database, for example Postgrex or Exqlite. The Driver decides the encoding of each value.

A Fragment in `#{}` **splices**. Its text and its Bindings enter the outer Fragment at that position. Any other value in `#{}` binds as one placeholder.

```elixir
cond_ = ~q"status = #{status}"
query = ~q"SELECT * FROM orders WHERE #{cond_} AND total > #{10}"

render(query, PlainSQL.Dialect.Postgres)
#=> {"SELECT * FROM orders WHERE status = $1 AND total > $2", ["open", 10]}
```

A reusable piece of SQL text is a `~q` module attribute. A String module attribute is a value. It binds.

```elixir
@open ~q"status = 'open'"

render(~q"SELECT * FROM orders WHERE #{@open} AND total > #{10}", PlainSQL.Dialect.SQLite)
#=> {"SELECT * FROM orders WHERE status = 'open' AND total > ?", [10]}

@open_text "status = 'open'"

render(~q"SELECT * FROM orders WHERE #{@open_text} AND total > #{10}", PlainSQL.Dialect.SQLite)
#=> {"SELECT * FROM orders WHERE ? AND total > ?", ["status = 'open'", 10]}
```

The second statement is valid SQL. SQLite casts the text to `0`. The query matches no row. The database reports no error.

Splicing is the base of every helper in the next section.

## Composition

A search form has optional filters. The status filter is set. The id filter may be empty. The query must include only the filters that are set.

Start with `where/1`. It takes a predicate Fragment and adds the `WHERE` keyword.

```elixir
status = "open"

render(~q"SELECT * FROM orders #{where(~q"status = #{status}")}", PlainSQL.Dialect.Postgres)
#=> {"SELECT * FROM orders WHERE status = $1", ["open"]}
```

The id filter is optional. `list/1` renders one placeholder per element inside parentheses. Write the filter as an expression that gives a Fragment or `false`:

```elixir
ids = []
by_id = ids != [] && ~q"id IN #{list(ids)}"
```

The `if` form gives `nil` in place of `false`:

```elixir
by_id = if ids != [], do: ~q"id IN #{list(ids)}"
```

`and_/1` takes a list of predicates and joins the present ones with `AND`. It skips `nil`, `false`, and `~q""`. These three values mean **absent**. Both forms above give an absent value for `[]`.

```elixir
conds = and_([~q"status = #{status}", by_id])
render(~q"SELECT * FROM orders #{where(conds)}", PlainSQL.Dialect.Postgres)
#=> {"SELECT * FROM orders WHERE (status = $1)", ["open"]}
```

With `ids = [1, 2]` the same code renders both predicates:

```elixir
#=> {"SELECT * FROM orders WHERE (status = $1) AND (id IN ($2, $3))", ["open", 1, 2]}
```

When every predicate is absent, `and_/1` returns `~q""`. This is the **Empty Fragment**. It has no text and no Bindings. Splicing it adds nothing. `where/1` renders nothing for it. The query stays valid with no filter at all.

`or_/1` joins with `OR`. It raises `ArgumentError` when every predicate is absent. `having/1` is `where/1` with `HAVING`.

`list([])` raises `ArgumentError`. `IN ()` is invalid SQL on every Dialect. An empty list has two possible meanings. The guard `ids != [] && ...` states "an empty list is no filter". The predicate `ids == [] && ~q"1 = 0"` states "an empty list matches no row". PlainSQL does not pick one. The developer writes the meaning.

On Postgres the array form needs no guard. A bare list in `#{}` binds as one value. The Driver sends it as an array. `id = ANY(#{ids})` matches no row for `[]`. `id <> ALL(#{ids})` matches every row for `[]`. The parameter count stays at one for any list length.

```elixir
ids = [1, 2]

render(~q"SELECT * FROM orders WHERE id = ANY(#{ids})", PlainSQL.Dialect.Postgres)
#=> {"SELECT * FROM orders WHERE id = ANY($1)", [[1, 2]]}
```

`ANY` and `ALL` with a subquery work on every Dialect. Splice the subquery: `~q"total > ALL (#{subquery})"`.

A report counts orders per status. Two parts of it are optional. A minimum count filters the groups. A second key sorts the groups by count.

`group_by/1` and `order_by/1` take a list of Fragments. They skip absent members and join the rest with `, `. `having/1` takes the optional filter.

```elixir
min = 2
by_count = true

group = group_by([~q"status"])
filter = having(min && ~q"count(*) > #{min}")
order = order_by([~q"status", by_count && ~q"count(*) DESC"])
render(~q"SELECT status, count(*) FROM orders #{group} #{filter} #{order}", PlainSQL.Dialect.Postgres)
#=> {"SELECT status, count(*) FROM orders GROUP BY status HAVING count(*) > $1 ORDER BY status, count(*) DESC", [2]}
```

With `min = nil` and `by_count = false` the same code renders no `HAVING` and one sort key:

```elixir
#=> {"SELECT status, count(*) FROM orders GROUP BY status  ORDER BY status", []}
```

An `UPDATE` has the same shape. `set/1` takes a list of assignments and joins the present ones with `, `.

```elixir
note = nil

assignments = set([~q"status = #{status}", note && ~q"note = #{note}"])
render(~q"UPDATE orders #{assignments} WHERE id = #{7}", PlainSQL.Dialect.Postgres)
#=> {"UPDATE orders SET status = $1 WHERE id = $2", ["open", 7]}
```

`set/1` differs in one point. It raises `ArgumentError` when every assignment is absent. `UPDATE` without `SET` is invalid SQL on every Dialect.

`where/1` has no such guard. `~q"DELETE FROM orders #{where(conds)}"` with every predicate absent deletes every row. `empty?/1` returns `true` for an absent value. Use it to refuse the statement:

```elixir
if empty?(conds), do: raise(ArgumentError, "DELETE needs a predicate")
```

There is no `limit/1`, `offset/1`, `returning/1`, or negation helper. Write them as text: `~q"LIMIT #{10}"`, `~q"NOT (#{pred})"`.

An `INSERT` built from a map takes the column names from the data. A name is not a value. The database does not accept a placeholder in place of a table or column name. `identifier/1` builds a Fragment with the name quoted for the Dialect. `join/2` places a separator Fragment between the members of a list.

```elixir
table = "orders"
names = ["id", "status"]
values = [1, "open"]

cols = join(Enum.map(names, &identifier/1), ~q", ")
render(~q"INSERT INTO #{identifier(table)} (#{cols}) VALUES #{list(values)}", PlainSQL.Dialect.MySQL)
#=> {"INSERT INTO `orders` (`id`, `status`) VALUES (?, ?)", [1, "open"]}
```

`identifier/1` always quotes. On Postgres `identifier("Users")` renders `"Users"`. That names a different table from unquoted `Users`. Postgres folds an unquoted identifier to lower case, so unquoted `Users` is the table `users`.

`join/2` skips absent members, like the other list helpers. A multi-row `VALUES` is `join/2` over one `list/1` per row:

```elixir
rows = [[1, "open"], [2, "closed"]]

render(~q"INSERT INTO orders (id, status) VALUES #{join(Enum.map(rows, &list/1), ~q", ")}", PlainSQL.Dialect.Postgres)
#=> {"INSERT INTO orders (id, status) VALUES ($1, $2), ($3, $4)", [1, "open", 2, "closed"]}
```

SQL text held in a string at runtime, for example a query read from a configuration file, is not a Fragment. `raw/1` builds one from it. The text renders verbatim. Never pass text derived from user input.

## Execution

PlainSQL renders. The Driver executes. Pass the rendered pair to the Driver function.

```elixir
ids = [1, 2]

{:ok, conn} = Postgrex.start_link(hostname: "localhost", username: "postgres", database: "app")
{sql, params} = render(~q"SELECT * FROM orders WHERE id IN #{list(ids)}", PlainSQL.Dialect.Postgres)
Postgrex.query(conn, sql, params)
#=> {:ok, %Postgrex.Result{...}}
```

The application pins the Dialect and the Driver in one module per database it uses:

```elixir
defmodule MyApp.SQL do
  import PlainSQL

  def query(conn, fragment, opts \\ []) do
    {sql, params} = render(fragment, PlainSQL.Dialect.Postgres)
    Postgrex.query(conn, sql, params, opts)
  end
end

MyApp.SQL.query(conn, ~q"SELECT * FROM orders WHERE id = #{id}")
```

The same module holds the call to `Postgrex.stream/4`, to `MyApp.Repo.query/3` for an Ecto repo, or to a Driver with a param shape of its own. `Tds.query/4` takes each param as a `Tds.Parameter` named after its placeholder:

```elixir
{sql, params} = render(fragment, PlainSQL.Dialect.MSSQL)
params = Enum.with_index(params, fn value, i -> %Tds.Parameter{name: "@#{i + 1}", value: value} end)
Tds.query(conn, sql, params)
```

`Exqlite.Sqlite3` has no `query` function. The application prepares, binds, fetches, and releases the statement:

```elixir
{sql, params} = render(fragment, PlainSQL.Dialect.SQLite)
{:ok, statement} = Exqlite.Sqlite3.prepare(db, sql)
:ok = Exqlite.Sqlite3.bind(statement, params)
{:ok, rows} = Exqlite.Sqlite3.fetch_all(db, statement)
:ok = Exqlite.Sqlite3.release(db, statement)
```

PlainSQL has no dependency. The application adds the Driver to its own deps.

Every Dialect is Rendering-tested. The test suite executes rendered SQL on an in-memory SQLite database through Exqlite. No other database runs in the test suite.

## Design

PlainSQL changes two things in the SQL text. It puts a placeholder where a value goes. It puts delimiters around an Identifier. Both changes need no knowledge of what the SQL says.

Every feature below needs that knowledge. It needs PlainSQL to read the SQL text or to encode a value. The developer owns the text. The Driver owns the encoding. A library that takes part of either job covers the cases its author foresaw. It fails on the rest. PlainSQL takes part of neither job.

- **No SQL parsing.** A parser is one grammar per Dialect. Every construct outside the grammar is a bug report.
- **No query builder.** There is no `INSERT` from a map, no `limit/1`, no `ORDER BY` from a keyword list. A builder is a second language over SQL. It grows one function per SQL construct. The rule for a helper is fixed. A helper is a SQL keyword.
- **No transpiling between Dialects.** `LIMIT` stays `LIMIT` on MSSQL. `RETURNING` stays `RETURNING` on MySQL. A Dialect that rewrites text must read text. That is parsing.
- **No value conversion.** A `%Date{}` reaches the Driver as a `%Date{}`. The Driver encodes it for its wire protocol. A second encoder disagrees with the Driver on some type.
- **No execution and no Dialect inference.** Inference needs a table from connection module to Dialect and Driver. The table is closed. A Driver outside it needs a PlainSQL release. A Driver with a param shape of its own needs a row of code. The application module in [Execution](#execution) holds both facts for the Drivers it uses.
- **No default meaning for an empty list.** `IN ()` is invalid SQL. "No filter" and "no row" are both valid meanings. A default hides a bug in the other case.

## Portability

> PlainSQL renders one Fragment for one Dialect at a time. A Dialect decides the placeholder style and the identifier quoting. A Dialect does not change the SQL text. PlainSQL does not check that the SQL text is valid for the target database. The developer owns the SQL text.

Shipped Dialect modules:

| Module | Placeholder | Identifier delimiters |
|---|---|---|
| `PlainSQL.Dialect.Postgres` | `$1`, `$2`, ... | `"name"` |
| `PlainSQL.Dialect.SQLite` | `?` | `"name"` |
| `PlainSQL.Dialect.MySQL` | `?` | `` `name` `` |
| `PlainSQL.Dialect.MSSQL` | `@1`, `@2`, ... | `[name]` |

## Warning: `#{}` inside a quoted literal

Do not write a `#{}` inside SQL quotes:

```elixir
~q"SELECT * FROM users WHERE name = '#{name}'"
```

This renders `WHERE name = '$1'`. The database receives the string literal `$1`, not a Binding. Write the `#{}` without quotes:

```elixir
~q"SELECT * FROM users WHERE name = #{name}"
```

