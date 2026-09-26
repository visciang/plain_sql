# Composition model: Splicing semantics and clause helpers

Type: grilling
Status: resolved
Blocked by: 01

## Question

What are the exact rules of Fragment Splicing, and which clause helpers ship in the core?

Sub-questions to settle in one session:

1. Splicing rules: text joins with or without whitespace; binding order after a splice; an empty Fragment inside a Fragment.
2. Optional clauses: how a developer writes a `WHERE` that disappears when no condition is present.
3. Joining conditions: a helper for `AND`/`OR` over a list of Fragments, and what it renders for an empty list.
4. `IN` lists: a helper or an automatic expansion when the bound value is a list.
5. The boundary: which helpers are refused because they need grammar knowledge (clause reordering, `SELECT` column lists).

Leaning from charting: Splicing as the core, a small helper set, no SQL grammar parsing.

## Blocks

05, 08, 09, 10

## Answer

Decided 2026-09-26 in a grilling session. The sigil letter is pending ticket 03; the examples below use `~q` as a placeholder.

### Fragment model

- A Fragment is an ordered list of parts. A part is `{:text, binary}`, `{:binding, value}`, or `{:list, values}`.
- A Fragment stores no placeholder numbers. The Dialect assigns placeholders at Rendering, in part order.
- Splicing is list concatenation. The inner parts take the position of the `#{}` in the outer parts. A Fragment holds no nested Fragment after Splicing.

Rejected: numbered placeholders in the stored text with renumbering at Splicing (slonik, sea-query). That design needs a reserved marker in the SQL text and a validation pass.

### Splicing rules

1. Splicing is verbatim. It adds no whitespace. It does not normalise the sigil text. The developer owns every character of the SQL text.
2. Binding order is text order. Rendering numbers Bindings in the order of the rendered text.
3. A Fragment spliced twice contributes its Bindings twice. Each occurrence gets its own placeholder.
4. The empty Fragment is the sigil with empty text (`~q""`). Splicing it adds no text and no Bindings. There is no `empty/0` function.
5. `nil` inside `#{}` is a Binding of `NULL`. It is never the empty Fragment.

### Helpers in the core

`all/1`

- Takes a list. Joins the members with ` AND `.
- Wraps every member in parentheses, also a single member.
- Skips members that are `nil`, `false`, or the empty Fragment.
- Renders the empty Fragment when no member remains. The identity of `AND` is `TRUE`; in a `WHERE` this means no filter.

`any/1`

- Same as `all/1` with ` OR `.
- Raises `ArgumentError` when no member remains. The identity of `OR` is `FALSE`. The empty Fragment would select every row. MSSQL has no boolean literal, so no portable literal exists.

`where/1`

- Takes one Fragment. Renders `WHERE ` followed by the Fragment.
- Renders the empty Fragment when the argument is the empty Fragment.
- No `having/1`, `set/1`, `order_by/1`, or `group_by/1` in v1.

`list/1`

- Takes a list of values. Produces one `{:list, values}` part.
- Raises `ArgumentError` for an empty list. `IN ()` is invalid SQL on every Dialect. The helper cannot tell `IN` from `NOT IN`, so no literal is correct for both.
- A bare list inside `#{}` stays one `{:binding, list}` part. The Driver receives the list as one value.
- The Dialect decides the rendered text of a `{:list, values}` part. Ticket 04 fixes the divergence. Ticket 05 fixes the callback.

Rejected: automatic expansion of a list value by inspection of the text before `#{}`. It needs grammar knowledge and fails on casts (`IN #{ids}::int4[]`).

Idiom for an optional filter:

```elixir
conds = all([~q"status = #{status}", ids != [] && ~q"id IN #{list(ids)}"])
~q"SELECT * FROM orders #{where(conds)}"
```

### Boundary rule

A core helper takes Fragments or values, emits text at its own Splicing position, and never reads the text around it.

Refused by this rule: clause reordering, `SELECT` column-list builders, `INSERT` and `UPDATE SET` builders from a map, dynamic `ORDER BY` builders.

### Effects on the map

- `INSERT` and `UPDATE SET` builders from a map: Out of scope for v1.
- Ticket 09 keeps single identifiers and identifier lists.
- Ticket 04 decides the Rendering of `{:list, values}` per Dialect and the behaviour for a bare list value the Dialect cannot bind.
- Fog "List and array values" is covered by this answer and ticket 04. Removed from Not yet specified.
- Fog "bind the same value twice": settled by rule 3. Named bindings stay in the fog.
- `CONTEXT.md`: added **Empty Fragment**.
