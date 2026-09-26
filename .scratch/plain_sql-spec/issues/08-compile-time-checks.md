# Compile-time checks in the sigil

Type: grilling
Status: open
Blocked by: 02, 03

## Question

Which checks does the sigil macro perform at compile time, and how does each surface to the developer?

Leaning from charting: light checks only, no lexing of the SQL text.

From ticket 03: the macro raises `CompileError` on any sigil modifier. This is the first check.

Candidates:

1. A `#{}` that holds a compile-time string literal where SQL text is expected: reject, or bind as a value.
2. Unbalanced single quotes in the SQL text: warn, error, or ignore.
3. A Fragment with zero bindings and zero splices: allow as a constant.
4. Anything that requires knowing whether a `#{}` sits in identifier or value position: refused, because it needs grammar knowledge.

For each: in or out, and the error kind (`CompileError`, warning, none).

## Blocks

10
