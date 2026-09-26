# Execution seam: render-only or a thin `query/2`

Type: grilling
Status: resolved
Blocked by: 05, 06

## Question

Does v1 ship an optional execution function on top of the render-only core, and what is its shape?

Settled during charting: the core is render-only. This ticket decides the optional layer.

Settle:

1. In or out for v1.
2. If in: `PlainSQL.query(conn_or_repo, fragment)` signature, how the Dialect is chosen (from ticket 06 findings or explicit), and the return value (the Driver's result untouched).
3. Where it lives: same package, a `plain_sql_ecto`-style companion, or an example in the docs.

## Blocks

10

## Answer

Decided 2026-09-26 in a grilling session.

### In for v1: two functions

`PlainSQL` gains `dialect/1` and `query/3`. Both live in the core package. There is no `query!/3`, no `stream`, no `prepare`, and no result mapping.

```elixir
@spec dialect(conn_or_repo :: DBConnection.conn() | module()) :: module()
@spec query(conn_or_repo, PlainSQL.Fragment.t(), opts :: keyword()) :: term()
```

Rejected: render-only with a README pattern. The two-line pattern states a Dialect module next to a connection that already knows it. Rejected: a wide layer with `query!/3` and pass-throughs. One function keeps the core a Rendering library with a dispatch, not a Driver.

### `dialect/1`

`dialect/1` returns one of the four shipped Dialect modules for a live connection or an Ecto repo module. It is the building block of `query/3`. It is public so that a caller can reach Driver functions `query/3` does not cover (`Postgrex.prepare`, Exqlite streaming, `Ecto.Adapters.SQL.query/4` inside a transaction).

Inference table, from [Dialect inference](06-dialect-inference.md):

| Source | Call | Result | Dialect |
|---|---|---|---|
| `DBConnection.conn()` | `DBConnection.connection_module/1` | `Postgrex.Protocol` | `PlainSQL.Dialect.Postgres` |
| | | `Exqlite.Connection` | `PlainSQL.Dialect.SQLite` |
| | | `MyXQL.Connection` | `PlainSQL.Dialect.MySQL` |
| | | `Tds.Protocol` | `PlainSQL.Dialect.MSSQL` |
| repo module | `repo.__adapter__/0` | `Ecto.Adapters.Postgres` | `PlainSQL.Dialect.Postgres` |
| | | `Ecto.Adapters.SQLite3` | `PlainSQL.Dialect.SQLite` |
| | | `Ecto.Adapters.MyXQL` | `PlainSQL.Dialect.MySQL` |
| | | `Ecto.Adapters.Tds` | `PlainSQL.Dialect.MSSQL` |

PlainSQL owns this table. The table is closed. A fifth Dialect module is reachable through `render/2` only.

### Dispatch rule: repo or connection

An atom that exports `__adapter__/0` is a repo. Every other value is a `DBConnection.conn()`: a pool pid, a registered name, a `{:via, _, _}` tuple, or the `%DBConnection{}` handle inside `run/3` and `transaction/3`. A repo pid is not accepted on the repo path.

Rejected: an option that names the kind. One `function_exported?/3` check decides it.

### `query/3`

`query(conn_or_repo, fragment, opts \\ [])`:

1. `dialect = dialect(conn_or_repo)`.
2. `{sql, params} = render(fragment, dialect)`.
3. Connection path: `Driver.query(conn, sql, params, opts)` with the Driver module from the same table row (`Postgrex`, `Exqlite`, `MyXQL`, `Tds`).
4. Repo path: `repo.query(sql, params, opts)`, the function `use Ecto.Adapters.SQL` injects. It honours `put_dynamic_repo/1`; `Ecto.Adapters.SQL.query(repo, ...)` does not.

The return value is the Driver result untouched. `opts` reaches the Driver unchanged. PlainSQL reads no key from `opts`.

The Empty Fragment renders `{"", []}` and reaches the Driver as an empty statement. PlainSQL does not check it.

### Tds param shape

The Tds row wraps each rendered param with `struct(Tds.Parameter, name: "@#{n}", value: v)` in list order before the `Tds.query/4` call. This is the form the Tds README documents. It is the one Driver-specific clause in `query/3`.

Rejected: a plain list. `Tds.Parameter.prepare_params/1` names a plain list `@1..@n`, but the module is `@moduledoc false`. Rejected: no Tds row. `dialect/1` returns `PlainSQL.Dialect.MSSQL` for a Tds connection; `query/3` must dispatch it.

MSSQL and MySQL dispatch is not tested against a live database. The 05 test rule stands.

### Failure

`dialect/1` raises `ArgumentError` when `DBConnection.connection_module/1` returns `:error` (custom pool, non-pool pid, `PartitionSupervisor` pid) or returns a module with no table row. `query/3` raises the same error before Rendering. The message names the value.

Rejected: a `dialect:` override key in `opts`. It puts a PlainSQL key inside a Driver option list; a caller with a custom pool uses `render/2` plus the Driver call. Rejected: an `{:error, reason}` return. `render/2` raises; `query/3` matches it.

### Packaging

Same package. `db_connection` and `ecto_sql` are `optional: true` deps. Driver modules appear as atoms in the table and are called with `apply/3`. Compilation without the optional deps present must be warning-free. The mechanism (`Code.ensure_loaded?/1` guard or `apply/3`) is the implementer's choice.

Rejected: a `plain_sql_ecto` companion. Two functions and a four-row table do not carry a second package.

### Effects on the map

- Fog "Packaging" is closed: everything is in the core package.
- Fog "Ecto interop": the repo path of `query/3` settles the first half. The `~q` Fragment inside an Ecto `fragment/1` is ruled out of scope: it needs Ecto's `?` placeholder and a compile-time literal, which is macro work against `Ecto.Query`, not Rendering.
- Fog "Error surface": `dialect/1` adds one `ArgumentError` case.
- Ticket 10: section 5 of the spec has content.
- `CONTEXT.md`: no new term. `dialect/1` and `query/3` use Dialect, Driver, and Rendering as defined.
