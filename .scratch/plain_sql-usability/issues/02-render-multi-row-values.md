# 02: Render multi-row `VALUES` with `values/1`

**Spec:** `docs/spec.md` section 2.4 (helpers, idioms), section 2.6 (errors), section 6 (out of scope).

**What to build:** A developer inserts many rows with one helper. `values(rows)` takes a list of rows. Each row is a list of values. The helper renders `VALUES ` followed by one parenthesized placeholder group for each row, joined with `, `. The helper follows the naming rule and the boundary rule of section 2.4. It is not the `INSERT` builder from a map that section 6 rules out.

PlainSQL does not compare row lengths. The database reports a row length that does not match.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] `~q"INSERT INTO t (a, b) #{values([[1, "x"], [2, "y"]])}"` renders `INSERT INTO t (a, b) VALUES ($1, $2), ($3, $4)` with params `[1, "x", 2, "y"]` on Postgres.
- [ ] The same Fragment renders the correct placeholders on SQLite, MySQL, and MSSQL.
- [ ] The rendered SQLite `INSERT` executes on SQLite and inserts two rows.
- [ ] `values([[1]])` renders `VALUES ($1)`.
- [ ] `values([])` raises `ArgumentError`. `INSERT` without rows is invalid SQL on every Dialect.
- [ ] `values/1` raises `ArgumentError` for an argument that is not a list, and for a row that is not a non-empty list.
- [ ] Spec section 2.4 documents `values/1`. The `INSERT` idiom in section 2.4 and the multi-row example in the README use `values/1` in place of `join/2` over `list/1`.
- [ ] Spec section 2.6 lists the new error cases.
