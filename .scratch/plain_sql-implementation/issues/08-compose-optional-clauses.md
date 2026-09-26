# 08: Compose optional clauses

**Spec:** `docs/spec.md` section 2.4 (skip rule, argument rule, `empty?/1`, `having/1`, `group_by/1`, `order_by/1`, `set/1`), section 2.6.

**What to build:** A developer builds a `SELECT` or `UPDATE` whose `HAVING`, `GROUP BY`, `ORDER BY`, or `SET` clause depends on which members the caller supplies. `where/1` and `having/1` take one Fragment and accept `nil` and `false` as the Empty Fragment. `group_by/1`, `order_by/1`, and `set/1` take a list, skip absent members, and join the rest with `, `. `empty?/1` tests for the Empty Fragment. Every wrong argument raises `ArgumentError` at the call.

Decisions: grilling session 2026-09-26. Named siblings, not a generic prefix helper. No `optional/2`, no `negate/1`, no binary separator, no `limit/1`, `offset/1`, `returning/1`.

**Blocked by:** 03 (Compose optional predicates).

**Status:** done

- [x] `where(nil)` and `where(false)` render the Empty Fragment. `where(1)` raises `ArgumentError`.
- [x] `empty?(~q"")`, `empty?(nil)`, `empty?(false)` return `true`. `empty?(~q"a")` returns `false`. `empty?(1)` raises `ArgumentError`.
- [x] `having(~q"count(*) > #{1}")` renders `HAVING count(*) > $1` with params `[1]` on Postgres. `having(~q"")`, `having(nil)`, `having(false)` render the Empty Fragment.
- [x] `group_by([~q"a", nil, ~q"b"])` renders `GROUP BY a, b`. `group_by([])` renders the Empty Fragment.
- [x] `order_by([~q"a DESC", false, ~q"b"])` renders `ORDER BY a DESC, b`. `order_by([nil])` renders the Empty Fragment.
- [x] `set([~q"a = #{1}", nil, ~q"b = #{2}"])` renders `SET a = $1, b = $2` with params `[1, 2]`. `set([])` and `set([nil, false, ~q""])` raise `ArgumentError`.
- [x] No member of `group_by/1`, `order_by/1`, `set/1` is wrapped in parentheses.
- [x] `group_by/1`, `order_by/1`, `set/1` raise `ArgumentError` for a member that is not a Fragment, `nil`, or `false`.
- [x] `join/2`, `and_/1`, `or_/1`, `group_by/1`, `order_by/1`, `set/1` raise `ArgumentError` for a `fragments` argument that is not a list. Added after code review.
- [x] The `UPDATE` idiom of spec 2.4 renders on Postgres and executes on SQLite.
- [x] README documents the new helpers, `~q"NOT (#{pred})"`, and the multi-row `VALUES` idiom.
