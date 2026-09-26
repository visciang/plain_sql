# Compile-time checks in the sigil

Type: grilling
Status: resolved
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

## Answer

Decided 2026-09-26 in a grilling session.

### Facts (Elixir 1.20.4)

- A string literal in `#{}` reaches the macro as a bare binary argument of `Kernel.to_string/1`.
- An empty `#{}` reaches the macro as `{:__block__, _, []}`. It evaluates to `nil`.
- Kernel sigils raise `ArgumentError` from the macro on a bad modifier. `~w"a b"x` raises `modifier must be one of: s, a, c`. The compiler reports the raise as a compile failure with file and line.
- `CompileError` needs `file:` and `line:` from `__CALLER__` and prefixes the message with `file:line:`.
- A sigil in pattern position fails in Elixir itself. A macro call is not a pattern.

### Decisions

1. Exception module: every compile-time rejection raises `ArgumentError` from the macro. This amends ticket 03 decision 3, which named `CompileError`. Rejected: `CompileError`. It needs file and line plumbing for the same result.
2. Checks in the sigil macro, complete list:
   - Any sigil modifier: `ArgumentError`.
   - An empty `#{}`: `ArgumentError`. The AST proves the expression is empty. It is never a valid Binding.
3. No check on a string literal in `#{}`. The literal binds as a value at runtime under ticket 03 rule 2. Rejected: a warning or error by AST shape. Ticket 03 rejected a second rule by AST shape.
4. No check on the SQL text. The macro does not read the text for quote balance or for a `#{}` inside quotes. A Fragment is partial by design, so quote balance is not a property of one sigil. Rejected: a `'#{` heuristic. It has false positives and is the first step onto lexing. The README documents the `'#{name}'` mistake.
5. A Fragment with no `#{}` is a plain Fragment. No check.
6. Refused: any check that needs the position of a `#{}` in the SQL grammar (identifier or value position).
7. No configuration for the checks. No strict mode.

### Effects on the map

- Ticket 03 decision 3: read `CompileError` as `ArgumentError`.
- Fog "Error surface": the compile-time cases are settled. The message text stays in the fog.
- Ticket 10: the README carries a note on Bindings inside quoted literals.
