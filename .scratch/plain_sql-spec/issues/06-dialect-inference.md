# Dialect inference from a connection or repo

Type: research
Status: resolved
Blocked by: none

## Question

Given a live connection or an Ecto repo, can a library discover which Dialect to render for, without configuration?

Check from primary sources (library source code and hexdocs):

1. Postgrex: what a connection pid or `DBConnection` handle exposes.
2. Exqlite and `ecto_sqlite3`: same.
3. MyXQL and Tds: same.
4. Ecto: `Repo.__adapter__/0` and `Ecto.Adapters.SQL` entry points that accept `{sql, params}`.
5. Whether `DBConnection` carries the connection module in a way a caller can read.

Record the concrete call for each Driver, or state that none exists.

## Blocks

07

## Answer

Findings: [docs/research/dialect-inference.md](../../../docs/research/dialect-inference.md), commit `4ab99aa`.

Yes, without configuration, through two public calls:

- `DBConnection.connection_module(conn)` returns `{:ok, Postgrex.Protocol | Exqlite.Connection | MyXQL.Connection | Tds.Protocol}`. Works on a pool pid and on the `%DBConnection{}` handle inside `run/3` and `transaction/3` (verified with Exqlite). Returns `:error` for a custom pool that does not call `register_as_pool/1`, for a `PartitionSupervisor` pid (Ecto `pool_count > 1`), and for any non-pool pid.
- `repo.__adapter__()` returns `Ecto.Adapters.Postgres | SQLite3 | MyXQL | Tds`. Compile-time value, needs no running repo.

Constraints:

- PlainSQL owns the four-entry table from connection module to Dialect. No Driver exposes its placeholder style as a function or constant.
- No Driver `query` function accepts a `{sql, params}` tuple. All take `sql` and `params` as two arguments. `Ecto.Adapters.SQL.to_sql/3` is the precedent for a `{sql, params}` return.
- The Ecto seam can call `Ecto.Adapters.SQL.query(repo, sql, params, opts)` directly after Rendering.
- Tds accepts a plain value list named `@1..@n` in list order, through a `@moduledoc false` module. A SQL Server Dialect that renders `@1..@n` depends on that private rule or on the public `Ecto.Adapters.Tds.Connection.prepare_params/1`.
