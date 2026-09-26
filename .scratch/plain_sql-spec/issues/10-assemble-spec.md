# Assemble the spec

Type: task
Status: open
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
