# Sigil name and the Binding rule for `#{}`

Type: prototype
Status: open
Blocked by: none

## Question

Which sigil letter does `plain_sql` use, and what does each `#{}` inside it become?

Build a throwaway sigil macro that:

1. Receives the `{:<<>>, _, parts}` AST (verified on Elixir 1.20.4, see map Notes).
2. Turns a `#{}` holding a Fragment into a Splice and any other `#{}` into a Binding.
3. Shows the result for three inputs: a flat query, a query with a spliced Fragment, and a query with a list value.

Decide from the prototype:

- The sigil letter. Candidates: `~q`, `~p`, `~SQL` with a custom marker (fallback if `#{}` proves unworkable).
- Whether the Fragment-versus-value decision happens at compile time (by AST shape) or at runtime (by struct match).
- Sigil modifiers, if any (for example a Dialect hint).

## Blocks

08, 10
