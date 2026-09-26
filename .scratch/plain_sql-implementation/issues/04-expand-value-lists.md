# 04: Expand value lists

**Spec:** `docs/spec.md` section 2.4 (`list/1`), section 2.5 part table, section 2.6.

**What to build:** A developer writes `id IN #{list(ids)}` and the query renders one placeholder per element inside parentheses on every Dialect. The same call serves `NOT IN` and a `VALUES` row. A bare list in `#{}` stays one Binding, so `id = ANY(#{ids})` reaches Postgres as one array value.

**Blocked by:** 01 (Render bound and spliced Fragments).

**Status:** done

- [x] `~q"id IN #{list([1, 2, 3])}"` renders `id IN ($1, $2, $3)` with params `[1, 2, 3]` on Postgres, `id IN (?, ?, ?)` on SQLite and MySQL, and `id IN (@1, @2, @3)` on MSSQL.
- [x] `list/1` raises `ArgumentError` at the call for `[]`.
- [x] `list/1` produces one `{:list, values}` part. The values are unchanged.
- [x] A `{:list, values}` part between other Bindings takes the placeholders `n..n+k-1` and the following Binding takes `n+k`.
- [x] `~q"id = ANY(#{ids})"` with `ids = [1, 2]` renders one placeholder and params `[[1, 2]]`.
- [x] `~q"VALUES #{list(values)}"` renders one row with parentheses included.
- [x] The `@doc` of `list/1` states that PlainSQL does not count parameters and the Driver reports its limit.
