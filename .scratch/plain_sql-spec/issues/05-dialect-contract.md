# Dialect contract and Rendering output

Type: grilling
Status: resolved
Blocked by: 02, 04

## Question

What is the Dialect behaviour, and what does Rendering return?

Settle:

1. The callbacks a Dialect module implements, derived from the divergence list of ticket 04.
2. The Rendering output: a `{sql, params}` tuple, or a struct that Drivers and Ecto accept.
3. How a contributor adds MySQL or MSSQL without touching the core, shown as the module skeleton.
4. Whether a Dialect is passed explicitly on every Rendering call or can be a process or application default.

## Blocks

07, 10

## Answer

Decided 2026-09-26 in a grilling session.

### Dialect behaviour

A Dialect is a module with `@behaviour PlainSQL.Dialect`. The behaviour has two callbacks:

```elixir
@callback placeholder(position :: pos_integer()) :: String.t()
@callback identifier_delimiters() :: {open :: String.t(), close :: String.t()}
```

The list is closed. It follows the divergence list of [Portability statement](04-portability-statement.md).

Rejected: a `use PlainSQL.Dialect` macro. Two one-line functions need no generation. Rejected: a Dialect as a struct. The inference table of [Dialect inference](06-dialect-inference.md) maps a connection module to a module, and a contributor writes a module.

### Shipped Dialect modules

The core ships four modules under the behaviour namespace:

| Module | `placeholder(n)` | `identifier_delimiters()` |
|---|---|---|
| `PlainSQL.Dialect.Postgres` | `"$#{n}"` | `{"\"", "\""}` |
| `PlainSQL.Dialect.SQLite` | `"?"` | `{"\"", "\""}` |
| `PlainSQL.Dialect.MySQL` | `"?"` | ``{"`", "`"}`` |
| `PlainSQL.Dialect.MSSQL` | `"@#{n}"` | `{"[", "]"}` |

Tests for MySQL and MSSQL are Rendering-only. No database runs in the test suite for them.

Rejected: Postgres and SQLite only. The Notes require that MySQL and MSSQL are addable without core changes. That is a property of the behaviour. Shipping the modules does not weaken it, and ticket 07 needs a target module for each entry of the inference table. Rejected: `SQLServer` or `Tds` as the name. The Dialect names the SQL variant, not the Driver. Rejected: Ecto-style plural `PlainSQL.Dialects.*`. One namespace, the behaviour is the parent.

### Contributor skeleton

A new Dialect is one module. There is no registration step.

```elixir
defmodule PlainSQL.Dialect.MSSQL do
  @behaviour PlainSQL.Dialect

  @impl true
  def placeholder(position), do: "@#{position}"

  @impl true
  def identifier_delimiters, do: {"[", "]"}
end
```

The `PlainSQL.Dialect` moduledoc carries this skeleton as the "add a Dialect" guide.

### Rendering output

`PlainSQL.render(fragment, dialect) :: {sql :: String.t(), params :: [term()]}`.

- `sql` is a binary. Rendering flattens the iodata once at the end.
- `params` holds one entry per `{:binding, value}` part and one entry per element of a `{:list, values}` part, in text order.
- The Empty Fragment renders `{"", []}`.
- `render/2` raises `ArgumentError` for an identifier with an embedded delimiter. There is no `{:ok, _} | {:error, _}` form.
- `render/2` does not check that the Dialect module implements the behaviour. A missing callback fails with `UndefinedFunctionError`, which names the module and the function.

Rejected: `sql` as `iodata()`. Golden tests and logs read a binary directly; the cost is one flatten per render. Rejected: a `%PlainSQL.Query{}` struct. No Driver takes it. The tuple matches `Ecto.Adapters.SQL.to_sql/3` and destructures into `Postgrex.query(conn, sql, params)`. Rejected: a `function_exported?/3` check in `render/2`. It costs two calls per render for a programmer error that the first test surfaces.

### Embedded-delimiter rule for a pair

Rendering raises `ArgumentError` when an identifier name contains the open delimiter or the close delimiter. The rule is the same for every Dialect. For MSSQL both `[` and `]` raise.

Rejected: the close delimiter only. One rule for every Dialect is simpler, and a `[` inside an identifier name is a bug or an attack in every case PlainSQL serves.

### Public module layout

- `PlainSQL`: `sigil_q/2`, `and_/1`, `or_/1`, `where/1`, `list/1`, `render/2`. The developer writes `import PlainSQL`.
- `PlainSQL.Fragment`: the struct only. `@type part :: {:text, String.t()} | {:binding, term()} | {:list, [term()]}`. Ticket 09 may add a part type.
- `PlainSQL.Dialect`: the behaviour and the four implementations under it.

Rejected: helpers in `PlainSQL.Fragment`. Two imports for one library.

### Dialect selection

`render/2` takes the Dialect module on every call. There is no `render/1`, no application default, no process default, and no atom shorthand (`:postgres`).

Rejected: an application default. An application with two databases has no single Dialect, and the default hides the Dialect from the reader. Rejected: an atom table. It is the core change the Notes rule out for a new Dialect. The one place a Dialect becomes implicit is next to a connection or repo. That is ticket 07, supplied by [Dialect inference](06-dialect-inference.md).

### Effects on the map

- Ticket 07 is unblocked. Its Dialect argument is a module; inference from a connection or repo returns one of the four shipped modules.
- Ticket 09: the identifier part renders with `identifier_delimiters/0`; the embedded-delimiter check covers both characters of the pair.
- Fog "Packaging": the four Dialect modules are in the core package. The open part is whether an Ecto bridge, if ticket 07 wants one, is a separate package.
- Fog "Error surface": `UndefinedFunctionError` for a Dialect module without a callback is not a PlainSQL exception. No new exception module from this ticket.
