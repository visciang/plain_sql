# Execution seam: render-only or a thin `query/2`

Type: grilling
Status: open
Blocked by: 05, 06

## Question

Does v1 ship an optional execution function on top of the render-only core, and what is its shape?

Settled during charting: the core is render-only. This ticket decides the optional layer.

Settle:

1. In or out for v1.
2. If in: `PlainSQL.query(conn_or_repo, fragment)` signature, how the Dialect is chosen (from ticket 06 findings or explicit), and the return value (the Driver's result untouched).
3. Where it lives: same package, a `plain_sql_ecto`-style companion, or an example in the docs.

## Blocks

10
