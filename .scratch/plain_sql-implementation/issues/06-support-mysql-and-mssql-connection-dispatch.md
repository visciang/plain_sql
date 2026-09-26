# 06: Support MySQL and MSSQL connection dispatch

**Spec:** `docs/spec.md` section 5.1 (connection rows for MyXQL and Tds), 5.2 (Tds param shape), 5.3.

**What to build:** A developer with a MyXQL or Tds connection calls `PlainSQL.query/3` and `PlainSQL.dialect/1`. Inference returns `PlainSQL.Dialect.MySQL` or `PlainSQL.Dialect.MSSQL`. The Tds path wraps each rendered param in a `Tds.Parameter` struct named after its placeholder. No MySQL or MSSQL database runs in the test suite. The tests verify the dispatch and the param shape in isolation.

**Blocked by:** 05 (Execute through Postgres and SQLite connections).

**Status:** done

- [x] `dialect/1` maps `MyXQL.Connection` to `PlainSQL.Dialect.MySQL` and `Tds.Protocol` to `PlainSQL.Dialect.MSSQL`.
- [x] The MyXQL path calls `MyXQL.query(conn, sql, params, opts)` with the rendered params unchanged.
- [x] The Tds path calls `Tds.query(conn, sql, params, opts)` with `params` as a list of `Tds.Parameter` structs. Struct `n` has `name: "@#{n}"` and `value: v` in list order.
- [x] `~q"a = #{1} AND b IN #{list([2, 3])}"` on the Tds path produces three `Tds.Parameter` structs named `@1`, `@2`, `@3` with values `1`, `2`, `3`.
- [x] The Tds wrap is the only Driver-specific clause in `query/3`.
- [x] The inference table has four connection rows and is closed. A fifth connection module raises `ArgumentError`.
- [x] `mix compile --warnings-as-errors` is clean with `myxql` and `tds` absent from the deps.
- [x] The README states that MySQL and MSSQL are Rendering-tested only.
