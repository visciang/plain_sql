# Sigil name and the Binding rule for `#{}`

Type: prototype
Status: resolved
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

## Answer

Decided 2026-09-26 from the prototype. Prototype: branch `prototype/sigil`, file `.scratch/plain_sql-spec/prototypes/sigil.exs`. Run: `elixir .scratch/plain_sql-spec/prototypes/sigil.exs`.

### Facts from the prototype (Elixir 1.20.4)

- A lowercase sigil macro receives `{:<<>>, _, parts}` for every input, also for `~q""` and for text with no `#{}`. Each `#{}` arrives as a `Kernel.to_string/1` call tagged `from_interpolation: true`. The macro replaces the call with a Binding.
- A multi-letter sigil must be uppercase. An uppercase sigil receives a plain binary with `#{}` as literal text. `~SQL` needs a custom marker.
- Kernel sigils: `~c ~r ~s ~w ~C ~D ~N ~R ~S ~T ~U ~W`. `~q` is free. `~p` is Phoenix verified routes.
- A Fragment in a variable and a Fragment written inline produce identical parts. The AST shape cannot tell a Fragment variable from a value variable.
- `~q""` gives `[{:text, ""}]`.
- Text is verbatim. `\n` stays two characters. `\"` becomes `"`. Alternate delimiters (`~q|...|`) and the heredoc form (`~q"""`) work. The heredoc form strips the indentation.
- Modifiers reach the macro as a charlist.
- The same Fragment spliced twice gives two Bindings. Rule 3 of ticket 02 holds.

### Decisions

1. Sigil: `~q`. Rejected: `~p` (Phoenix collision), `~SQL` (no native `#{}`, needs a custom marker).
2. Binding rule: at runtime, by struct match. A `%PlainSQL.Fragment{}` inside `#{}` splices. Any other value binds as one `{:binding, value}` part. There is no compile-time rule by AST shape. Rejected: a compile-time fast path for an inline `~q`. It adds a second rule for the same behaviour.
3. Modifiers: none in v1. The macro raises `CompileError` on any modifier. Rejected: a Dialect hint modifier. The Dialect is chosen at Rendering.
4. The macro drops `{:text, ""}` parts. The Empty Fragment is `%PlainSQL.Fragment{parts: []}`. `and_/1` tests `parts == []`.
5. Text rule for the spec: the sigil text is verbatim. The only transform is the delimiter escape. The heredoc form `~q"""` is the documented form for multi-line SQL.
6. Values: the sigil never converts a value. `%Date{}`, `%Decimal{}`, a list, a map bind as one value. The Driver decides the encoding. Only `%PlainSQL.Fragment{}` is special to the sigil.

### Effects on the map

- Ticket 08: first entry is the `CompileError` on any modifier.
- Ticket 09: an identifier or raw-text marker, if wanted, is a further struct that the sigil treats like a Fragment.
