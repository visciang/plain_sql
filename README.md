# PlainSQL

An Elixir library for writing SQL as SQL. The developer writes SQL text in the `~q` sigil. A Fragment in `#{}` splices. Any other value in `#{}` binds. `render/2` returns the SQL string and the ordered value list for one Dialect.

PlainSQL does not parse SQL. PlainSQL does not contain a Driver.

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

```elixir
import PlainSQL

status = "open"
cond_ = ~q"status = #{status}"

query = ~q"SELECT * FROM orders WHERE #{cond_} AND total > #{10}"

render(query, PlainSQL.Dialect.Postgres)
#=> {"SELECT * FROM orders WHERE status = $1 AND total > $2", ["open", 10]}

render(query, PlainSQL.Dialect.SQLite)
#=> {"SELECT * FROM orders WHERE status = ? AND total > ?", ["open", 10]}
```

A `%PlainSQL.Fragment{}` in `#{}` splices its text and its Bindings at that position. Any other value binds as one placeholder. The sigil never converts a value. The Driver decides the encoding.

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

