# Composition model: Splicing semantics and clause helpers

Type: grilling
Status: open
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
