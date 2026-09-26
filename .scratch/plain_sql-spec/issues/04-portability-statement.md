# Portability statement and the closed divergence list

Type: grilling
Status: resolved
Blocked by: 01

## Question

What does `plain_sql` promise about portability, in one paragraph a developer can rely on, and which divergences does a Dialect handle?

Leaning from charting: the Dialect handles a closed list — placeholder style, identifier quoting, `IN` list expansion. Everything else is the developer's SQL text. Candidate statement: "One Fragment, rendered per Dialect. The Dialect changes how values and identifiers are bound, never what your SQL says."

Settle:

1. The final list, item by item, with the reason each is in or out.
2. The exact statement text for the README.
3. What Rendering does when a Fragment uses a construct the target Dialect cannot bind (for example a Postgres array value under SQLite): error, pass-through, or Dialect-defined.

Input from [Composition model](02-composition-model.md): `list/1` produces a `{:list, values}` part. This ticket decides its rendered text per Dialect (`($1, $2, $3)` versus `= ANY($1)`). A bare list value is one `{:binding, list}` part; item 3 covers the Dialect that cannot bind it.

## Blocks

05, 10

## Answer

Decided 2026-09-26 in a grilling session.

### Divergence list

A Dialect decides two things:

1. The placeholder text for the Binding at position N.
2. The identifier quoting delimiter pair.

The list is closed. A Dialect module has no other effect on the rendered text.

Items considered and kept out, with the reason:

- `IN` list expansion. Moved to the core (see below). The Dialect contributes only the placeholder text per element.
- Boolean literals, `LIMIT`/`TOP`, `RETURNING`. Rewriting SQL text. Out of scope by charter.
- String-literal escaping. PlainSQL never inlines a literal.
- Value encoding (`%Date{}`, arrays, `%Decimal{}`). The Driver owns it (ticket 03, decision 6).
- Identifier case folding. Not a Rendering concern.

### Rendering of `{:list, values}`

- Every Dialect renders `(p1, p2, ..., pn)`: one placeholder per element, separator `, `, parentheses included. Postgres `($1, $2, $3)`, SQLite `(?, ?, ?)`.
- The text works after `IN` and after `NOT IN`.
- The Postgres form `= ANY(...)` is not reachable from `list/1`. The word `IN` is in the developer's text. The Dialect does not rewrite it. The developer writes `id = ANY(#{ids})` for the Postgres form. The bare list binds as one array value with no parameter ceiling.
- Ceiling: one placeholder per element. SQLite accepts 32766 parameters (999 before 3.32.0), MSSQL 2100. PlainSQL does not count parameters. The Driver reports the limit.

Rejected: `(SELECT unnest($1))` with one array Binding under Postgres. Postgres cannot infer the array type of an untyped parameter to `unnest`. The statement fails at prepare time without a cast. Rejected: Dialect-defined free form. It reopens the divergence list.

### A value the Dialect cannot bind

Rendering never inspects a value. A bare list under SQLite, a map under Postgres, and a `%Decimal{}` under a Driver without Decimal support pass through. The Driver raises on execute with its own message.

Rejected: a per-Dialect table of bindable Elixir types with an `ArgumentError` at Rendering. The table is Driver knowledge. Exqlite and a different SQLite Driver accept different types. A Driver adds types through extensions.

### Placeholder text per Dialect

- Postgres: `$N`.
- SQLite: `?`. Rejected: `?NNN`. Rule 3 of ticket 02 gives every Binding occurrence its own placeholder. Numbered SQLite placeholders add nothing.
- Facts for Dialect authors: MySQL `?`, MSSQL `@N`.

### Identifier quoting per Dialect

- Postgres and SQLite: `"`. Facts for Dialect authors: MySQL `` ` ``, MSSQL `[` `]`.
- Rendering raises `ArgumentError` when an identifier name contains the Dialect's delimiter. This rule is the same for every Dialect. The Dialect contributes only the delimiter pair.

Rejected: doubling the embedded delimiter (`"us""ers"`). It accepts a bug and an injection attempt without a signal.

### README statement

> PlainSQL renders one Fragment for one Dialect at a time. A Dialect decides the placeholder style and the identifier quoting. A Dialect does not change the SQL text. PlainSQL does not check that the SQL text is valid for the target database. The developer owns the SQL text.

Rejected: the promise without the last two sentences. The survey found that no text library promises one SQL text runs everywhere. The surveyed libraries state this boundary in their documentation. Rejected: the charting candidate ("never what your SQL says") for its shorter form. The rewrite keeps one idea per sentence.

### Effects on the map

- Ticket 05: the Dialect behaviour has two callbacks, placeholder text for position N and the identifier delimiter pair. `{:list, values}` expansion and the embedded-delimiter check are core Rendering rules, not callbacks.
- Ticket 02 answer, section `list/1`: "The Dialect decides the rendered text of a `{:list, values}` part" is superseded. The core decides it; the Dialect contributes the placeholder text.
- Fog "Dialect-specific Fragments": ruled out of scope. A `dialect:` tag on a Fragment is a validation of the SQL text on behalf of the developer. The statement puts that text in the developer's hands.
- Fog "Error surface": two facts settled here. A value the Driver cannot bind raises in the Driver. An identifier with an embedded delimiter raises `ArgumentError` at Rendering. The compile-time part stays with ticket 08.
