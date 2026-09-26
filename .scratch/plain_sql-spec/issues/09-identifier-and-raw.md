# Identifier binding and the raw-text escape hatch

Type: grilling
Status: resolved
Blocked by: 02

## Question

How does a developer bind an identifier (table or column name) and how does a developer insert trusted raw SQL text, so that neither can be confused with a value Binding?

Settle:

1. Identifier binding: a function such as `ident("users")` that the Dialect quotes, or a sigil modifier.
2. Raw text: whether an escape hatch exists at all, its name, and the documentation warning that accompanies it.
3. Whether a plain string can ever splice as SQL text without an explicit marker. Leaning: no.
4. Composite identifiers (`schema.table`) and identifier lists (column lists for `INSERT`).

From ticket 03: sigil modifiers are out for v1, so option 1 is a function. The sigil treats only `%PlainSQL.Fragment{}` as special; an identifier or raw-text marker is a further part shape or struct that this ticket defines.

## Blocks

10

## Answer

Decided 2026-09-26 in a grilling session.

### Identifier

`identifier/1` in `PlainSQL`.

- Takes a binary. Any other value raises `ArgumentError` at the call.
- `""` raises `ArgumentError` at the call. The check needs no Dialect.
- Returns a Fragment with one `{:identifier, name}` part. `PlainSQL.Fragment.part` gains this fourth shape.
- The sigil needs no new rule. The result is a `%PlainSQL.Fragment{}`, so it splices.
- Rendering wraps the name in the pair from `identifier_delimiters/0`. Rendering always quotes. `identifier("Users")` renders `"Users"`. On Postgres this names a different table from unquoted `Users`.
- Rendering raises `ArgumentError` when the name contains the open or the close delimiter ([Dialect contract](05-dialect-contract.md)).
- No composite form. `identifier("public.users")` renders `"public.users"`, one name. The developer writes `#{identifier("public")}.#{identifier("users")}`. This matches Ecto's `identifier/1`.

Rejected: `ident/1`. The full word matches the Ecto precedent and the glossary. Rejected: atom input. One rule; `Atom.to_string/1` is one call at the call site. Rejected: a split on `.` inside the name (porsager). A column that contains `.` becomes unreachable. Rejected: a list form `identifier(["public", "users"])` (slonik). It adds a rule for one case that Splicing already covers.

### Raw Text

`raw/1` in `PlainSQL`.

- Takes a binary. Any other value raises `ArgumentError` at the call.
- Returns a Fragment with one `{:text, binary}` part. No new part type. `raw("")` is the Empty Fragment, the same as `~q""`.
- It serves SQL text not known at compile time, for example `File.read!("report.sql")`.
- `@doc` warning text: "The text renders verbatim. Never pass text derived from user input."

Rejected: no escape hatch. Runtime SQL text has no other way into a Fragment. Rejected: the name `unsafe/1` (porsager, slonik). The name states a judgement. `raw` states what the value is. The doc states the danger. Rejected: iodata input. Same rule as `identifier/1`.

A plain string in `#{}` never splices as SQL text. Settled by [Sigil name and the Binding rule](03-sigil-and-binding-rule.md), decision 2.

### `join/2`

`join/2` in `PlainSQL`. It covers identifier lists and every other list of Fragments.

- Takes a list of Fragments and a separator Fragment. Renders the members in order with the separator between them.
- Skips members that are `nil`, `false`, or the Empty Fragment. Same rule as `all/1`.
- Renders the Empty Fragment when no member remains.
- A member that is not a Fragment, `nil`, or `false` raises `ArgumentError`. `list/1` is the helper for values.
- `all/1` is `join/2` with ` AND ` plus parentheses around each member. `any/1` is the same with ` OR ` plus the raise on an empty result.

Column list idiom:

```elixir
cols = join(Enum.map(names, &identifier/1), ~q", ")
~q"INSERT INTO #{identifier(table)} (#{cols}) VALUES #{list(values)}"
```

Rejected: `identifiers/1`. It serves one list case. `join/2` serves every list case and is the primitive under `all/1` and `any/1`. Rejected: no helper. Reducing with Splicing is the same code in every project. Rejected: verbatim `join/2` that keeps the separator of an Empty Fragment member. `a, , b` is never the wanted text.

### Effects on the map

- Ticket 05, public module layout: `PlainSQL` gains `identifier/1`, `raw/1`, `join/2`. `PlainSQL.Fragment.part` gains `{:identifier, String.t()}`.
- Fog "Error surface": four new `ArgumentError` cases at the call, no new exception module. Non-binary or empty name in `identifier/1`; non-binary in `raw/1`; non-Fragment member in `join/2`.
- `CONTEXT.md`: added **Identifier** and **Raw Text**.
- Ticket 10 is unblocked.
