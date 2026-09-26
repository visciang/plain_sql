# 03: Compose optional predicates

**Spec:** `docs/spec.md` section 2.4 (`and_/1`, `or_/1`, `where/1`), section 2.6.

**What to build:** A developer builds a `SELECT` whose `WHERE` clause depends on which filters the caller supplies. `and_/1` and `or_/1` combine the present predicates with `AND` or `OR`. `where/1` emits `WHERE` only when at least one predicate remains. With no filter the query renders without a `WHERE` clause.

`join/2` from ticket 02 is the primitive under `and_/1` and `or_/1`.

**Blocked by:** 02 (Compose dynamic names and SQL text).

**Status:** done

- [x] `and_([~q"a = #{1}", ~q"b = #{2}"])` renders `(a = $1) AND (b = $2)` with params `[1, 2]` on Postgres.
- [x] `and_/1` and `or_/1` wrap a single remaining member in parentheses.
- [x] `and_/1` and `or_/1` skip `nil`, `false`, and the Empty Fragment.
- [x] `and_([])` and `and_([nil, false, ~q""])` render the Empty Fragment.
- [x] `or_([])` and `or_([nil, false, ~q""])` raise `ArgumentError` at the call.
- [x] `and_/1` and `or_/1` raise `ArgumentError` at the call for a member that is not a Fragment, `nil`, or `false`.
- [x] `where(fragment)` renders `WHERE ` followed by the Fragment. `where(~q"")` renders the Empty Fragment.
- [x] Nested `and_([or_([...]), ...])` numbers Bindings in text order across the nesting.
- [x] The `conds` idiom of spec 2.4 renders with the `WHERE` clause when a filter is present and without it when every filter is absent.
- [x] No `having/1`, `set/1`, `order_by/1`, or `group_by/1` exists.
