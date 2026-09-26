# 05: Execute through Postgres and SQLite connections

**Spec:** `docs/spec.md` section 5.1 (connection rows for Postgrex and Exqlite), 5.2 (connection path), 5.3.

**What to build:** A developer with a Postgrex or Exqlite connection calls `PlainSQL.query(conn, fragment, opts)`. PlainSQL infers the Dialect from the connection, renders the Fragment, and calls the Driver. The Driver result comes back untouched. `PlainSQL.dialect(conn)` alone returns the Dialect module for use with Driver functions that `query/3` does not cover.

This ticket adds `db_connection` as an optional dep and `postgrex` and `exqlite` as test deps. The test suite runs a live Postgres and a live SQLite database.

**Blocked by:** 01 (Render bound and spliced Fragments).

**Status:** ready-for-agent

- [ ] `dialect(conn)` returns `PlainSQL.Dialect.Postgres` for a Postgrex pool pid and `PlainSQL.Dialect.SQLite` for an Exqlite pool pid.
- [ ] `dialect/1` accepts a pool pid, a registered name, a `{:via, _, _}` tuple, and the `%DBConnection{}` handle inside `DBConnection.run/3` and `transaction/3`.
- [ ] `dialect/1` raises `ArgumentError` when `DBConnection.connection_module/1` returns `:error`. The message names the value.
- [ ] `dialect/1` raises `ArgumentError` for a connection module with no table row. The message names the module.
- [ ] `query(conn, fragment, opts)` raises on inference failure before Rendering. A Fragment with an embedded-delimiter identifier does not raise when inference fails first.
- [ ] `query/3` returns the `Postgrex.query/4` or `Exqlite.query/4` result untouched, both the `{:ok, _}` and the `{:error, _}` form.
- [ ] `opts` reaches the Driver unchanged. A test passes a Driver option and observes its effect.
- [ ] `query(conn, ~q"", [])` sends an empty statement to the Driver. PlainSQL does not check it.
- [ ] The default for `opts` is `[]`.
- [ ] `mix compile --warnings-as-errors` is clean with `db_connection`, `postgrex`, and `exqlite` absent from the deps.
- [ ] The README documents `query/3` and `dialect/1` with a Postgrex example and an Exqlite example.
