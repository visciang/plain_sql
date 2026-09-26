# Assemble the spec

Type: task
Status: resolved
Blocked by: 02, 03, 04, 05, 07, 08, 09

## Question

Write `docs/spec.md` from the resolved tickets. This is the destination of the map.

Contents, in order:

1. Purpose and the portability statement (ticket 04).
2. Public API: sigil, Fragment, helpers, Rendering (tickets 02, 03, 09).
3. Dialect contract and the two reference Dialects (ticket 05).
4. Compile-time checks (ticket 08).
5. Execution seam, if any (ticket 07).
6. Out of scope, copied from the map.

Verify: every public function in the spec traces to a resolved ticket, and every term matches `CONTEXT.md`.

## Blocks

none

## Answer

Done 2026-09-26. The spec is `docs/spec.md`.

Sections, in the order the question lists: purpose and portability statement; public API (Fragment, `~q`, Splicing rules, helpers, Rendering, errors); Dialect contract; compile-time checks; execution seam; out of scope. Two additions: section 7 lists the open items the implementation effort decides (error message text, test strategy, named bindings), and an appendix maps every public symbol to its ticket.

Verification:

- Every public symbol traces to a resolved ticket. The appendix table holds the mapping: `sigil_q/2` (03, 08), `Fragment` (02, 05, 09), `and_/1` `or_/1` `where/1` `list/1` (02), `join/2` `identifier/1` `raw/1` (09), `render/2` (05), `Dialect` behaviour and four modules (04, 05), `dialect/1` `query/3` (06, 07).
- Terms match `CONTEXT.md`. A grep for the avoided words (interpolation, escaping, nesting, concatenation, embedding, adapter, backend, flavour, serialisation, snippet, unsafe) finds only the Ecto identifiers `__adapter__/0` and `Ecto.Adapters.*`, the Elixir delimiter escape, and "embedded delimiter" as ticket 04 and 05 name it.
- One claim from the tickets was not carried: "Postgres and SQLite tests run against a live database". Ticket 05 fixes only that MySQL and MSSQL tests are Rendering-only. The test strategy stays an open item.
