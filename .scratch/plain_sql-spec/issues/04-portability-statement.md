# Portability statement and the closed divergence list

Type: grilling
Status: open
Blocked by: 01

## Question

What does `plain_sql` promise about portability, in one paragraph a developer can rely on, and which divergences does a Dialect handle?

Leaning from charting: the Dialect handles a closed list — placeholder style, identifier quoting, `IN` list expansion. Everything else is the developer's SQL text. Candidate statement: "One Fragment, rendered per Dialect. The Dialect changes how values and identifiers are bound, never what your SQL says."

Settle:

1. The final list, item by item, with the reason each is in or out.
2. The exact statement text for the README.
3. What Rendering does when a Fragment uses a construct the target Dialect cannot bind (for example a Postgres array value under SQLite): error, pass-through, or Dialect-defined.

## Blocks

05, 10
