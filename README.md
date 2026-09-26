# PlainSQL

An Elixir library for writing SQL as SQL. The developer writes the SQL text and puts each value in `#{}`. PlainSQL keeps the values out of the text, renders one placeholder per value in the style of the target database, and returns the SQL string with the ordered value list.

PlainSQL does not parse SQL. PlainSQL does not send queries to a database on its own.

## Installation

Add `plain_sql` to the dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:plain_sql, "~> 0.1.0"}
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

Splicing is the base of every helper in the next section.

## Composition

A Fragment with no text and no Bindings is the **Empty Fragment**. `~q""` is the Empty Fragment. Splicing the Empty Fragment adds nothing. An optional clause that is absent has this value.

`and_/1` and `or_/1` compose optional predicates. `where/1` and `having/1` add the clause keyword. Every helper treats `nil`, `false`, and the Empty Fragment as absent. `and_/1` and `or_/1` skip an absent member. `where/1` and `having/1` render nothing for an absent argument.

```elixir
status = "open"
ids = [1, 2]

conds = and_([~q"status = #{status}", ids != [] && ~q"id IN #{list(ids)}"])
render(~q"SELECT * FROM orders #{where(conds)}", PlainSQL.Dialect.Postgres)
#=> {"SELECT * FROM orders WHERE (status = $1) AND (id IN ($2, $3))", ["open", 1, 2]}
```

`list([])` raises `ArgumentError`. `IN ()` is invalid SQL on every Dialect. An empty list has two possible meanings. The guard `ids != [] && ...` states "an empty list is no filter". The predicate `ids == [] && ~q"1 = 0"` states "an empty list matches no row". PlainSQL does not pick one. The developer writes the meaning.

`group_by/1`, `order_by/1`, and `set/1` take a list. They skip absent members and join the rest with `, `. `set/1` raises `ArgumentError` when no member remains. `empty?/1` returns `true` for an absent value.

```elixir
min = 2
by_name = true
note = nil

group = group_by([~q"status"])
filter = having(min && ~q"count(*) > #{min}")
order = order_by([~q"status", by_name && ~q"count(*) DESC"])
render(~q"SELECT status, count(*) FROM orders #{group} #{filter} #{order}", PlainSQL.Dialect.Postgres)
#=> {"SELECT status, count(*) FROM orders GROUP BY status HAVING count(*) > $1 ORDER BY status, count(*) DESC", [2]}

assignments = set([~q"status = #{status}", note && ~q"note = #{note}"])
render(~q"UPDATE orders #{assignments} WHERE id = #{7}", PlainSQL.Dialect.Postgres)
#=> {"UPDATE orders SET status = $1 WHERE id = $2", ["open", 7]}
```

There is no `limit/1`, `offset/1`, `returning/1`, or negation helper. Write them as text: `~q"LIMIT #{10}"`, `~q"NOT (#{pred})"`.

`identifier/1` quotes a name for the Dialect. `join/2` places a separator between Fragments. `list/1` renders one placeholder per element inside parentheses.

```elixir
table = "orders"
names = ["id", "status"]
values = [1, "open"]

cols = join(Enum.map(names, &identifier/1), ~q", ")
render(~q"INSERT INTO #{identifier(table)} (#{cols}) VALUES #{list(values)}", PlainSQL.Dialect.MySQL)
#=> {"INSERT INTO `orders` (`id`, `status`) VALUES (?, ?)", [1, "open"]}
```

A multi-row `VALUES` is `join/2` over one `list/1` per row:

```elixir
rows = [[1, "open"], [2, "closed"]]

render(~q"INSERT INTO orders (id, status) VALUES #{join(Enum.map(rows, &list/1), ~q", ")}", PlainSQL.Dialect.Postgres)
#=> {"INSERT INTO orders (id, status) VALUES ($1, $2), ($3, $4)", [1, "open", 2, "closed"]}
```

`raw/1` splices SQL text known at runtime. The text renders verbatim. Never pass text derived from user input.

## Execution

`query/3` infers the Dialect from a live connection, renders the Fragment, and calls the Driver. The Driver result comes back untouched. `opts` reaches the Driver unchanged.

```elixir
ids = [1, 2]
id = 1

{:ok, conn} = Postgrex.start_link(hostname: "localhost", username: "postgres", database: "app")
PlainSQL.query(conn, ~q"SELECT * FROM orders WHERE id IN #{list(ids)}")
#=> {:ok, %Postgrex.Result{...}}

{:ok, conn} = Exqlite.start_link(database: "app.db")
PlainSQL.query(conn, ~q"SELECT * FROM orders WHERE id = #{id}", timeout: 1_000)
#=> {:ok, %Exqlite.Result{...}}
```

`dialect/1` returns the Dialect module alone. Use it with a Driver function that `query/3` does not cover.

```elixir
fragment = ~q"SELECT * FROM orders WHERE id = #{id}"

{sql, params} = render(fragment, PlainSQL.dialect(conn))
Postgrex.stream(conn, sql, params)
```

`conn` is a `DBConnection.conn()`: a pool pid, a registered name, a `{:via, _, _}` tuple, or the handle inside `DBConnection.run/3` and `DBConnection.transaction/3`. `dialect/1` raises `ArgumentError` for a value that is not a pool and for a connection module outside the table below.

| Connection module | Dialect | Driver call |
|---|---|---|
| `Postgrex.Protocol` | `PlainSQL.Dialect.Postgres` | `Postgrex.query/4` |
| `Exqlite.Connection` | `PlainSQL.Dialect.SQLite` | `Exqlite.query/4` |
| `MyXQL.Connection` | `PlainSQL.Dialect.MySQL` | `MyXQL.query/4` |
| `Tds.Protocol` | `PlainSQL.Dialect.MSSQL` | `Tds.query/4` with each param as a `Tds.Parameter` named `@n` |

`db_connection` is an optional dependency. Add the Driver to the deps of the application.

### Ecto repos

`query/3` and `dialect/1` accept an Ecto repo module. An atom that exports `__adapter__/0` is a repo. Every other value is a connection. A repo pid is not a repo.

```elixir
id = 1

PlainSQL.query(MyApp.Repo, ~q"SELECT * FROM orders WHERE id = #{id}")
#=> {:ok, %Postgrex.Result{...}}
```

The repo path calls `repo.query(sql, params, opts)`. It honours `put_dynamic_repo/1`. `ecto_sql` is an optional dependency.

| Ecto adapter | Dialect |
|---|---|
| `Ecto.Adapters.Postgres` | `PlainSQL.Dialect.Postgres` |
| `Ecto.Adapters.SQLite3` | `PlainSQL.Dialect.SQLite` |
| `Ecto.Adapters.MyXQL` | `PlainSQL.Dialect.MySQL` |
| `Ecto.Adapters.Tds` | `PlainSQL.Dialect.MSSQL` |

Postgres and SQLite are the reference Dialects. The test suite executes against both. MySQL and MSSQL are Rendering-tested only. No MySQL or MSSQL database runs in the test suite.

### Tests

`mix test` runs the SQLite tests on an in-memory database. The Postgres tests run only when `PG_URL` is set. `make db-up` starts a Postgres container and prints the `PG_URL` to export. `make db-down` stops it.

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

