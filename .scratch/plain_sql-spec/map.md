# Map: PlainSQL design spec

Label: wayfinder:map
Tracker: local markdown (`/Users/visciang/.agents/skills/setup-matt-pocock-skills/issue-tracker-local.md`). Tickets live in `issues/NN-<slug>.md`.

## Destination

A design spec for `plain_sql`, an Elixir library that lets a developer write SQL as SQL through a sigil, compose Fragments, and render one Fragment per Dialect. The spec fixes the public API, the composition model, and the portability statement. It is ready to hand to an implementation effort.

## Notes

- Domain: Elixir library design. Glossary in `/CONTEXT.md` (Fragment, Binding, Splicing, Dialect, Driver, Rendering). Use these terms in every ticket and answer.
- Skills every session consults: `grilling` and `domain-modeling` for every HITL ticket; `prototype` for prototype tickets; `research` for research tickets.
- Documentation style: `parla-come-mangi` (ASD-STE100) for every doc, answer, and comment.
- Plan, don't do. Tickets resolve decisions. Prototypes are throwaway.
- Prior art, read-only: `/Volumes/Code/personal/sql` (elixir-dbvisor/sql, Apache-2.0). It parses the full SQL/92 grammar, owns a pool and a Postgres wire protocol, and calls its placeholder renderers "adapters". `plain_sql` is a new library, not a fork.
- Reference Dialects for v1: Postgres and SQLite. MySQL and MSSQL must be addable as Dialect modules without core changes.
- Settled during charting (2026-09-26):
  - Name: `plain_sql`, module `PlainSQL`. Free on hex.pm at charting time.
  - Core is render-only. The Dialect is chosen at Rendering time. Execution belongs to Drivers.
  - Composition leaning: Fragment Splicing as the core, plus a small set of clause helpers. No SQL grammar parsing.
  - Binding marker leaning: lowercase sigil with native `#{}`. Verified 2026-09-26 on Elixir 1.20.4: a lowercase sigil macro receives the `{:<<>>, _, parts}` AST with each `#{}` as a `Kernel.to_string/1` call tagged `from_interpolation: true`, so the macro can bind instead of stringify.
  - Compile-time work leaning: light checks only, no lexing.

## Decisions so far

<!-- one line per resolved ticket: [title](issues/NN-slug.md): gist -->

- [Prior art survey: composable SQL-as-text libraries](issues/01-prior-art-survey.md): text-based libraries order Bindings by text position, treat the empty Fragment as first-class, change SQL text per Dialect only for `IN`, and none promises one SQL text runs everywhere.
- [Dialect inference from a connection or repo](issues/06-dialect-inference.md): yes, through `DBConnection.connection_module/1` and `repo.__adapter__/0`; PlainSQL owns the module-to-Dialect table; no Driver accepts a `{sql, params}` tuple.
- [Composition model: Splicing semantics and clause helpers](issues/02-composition-model.md): a Fragment is a parts list numbered at Rendering; Splicing is verbatim list concatenation; helpers `and_/1`, `or_/1`, `where/1`, `list/1`; a helper never reads the text around it.
- [Sigil name and the Binding rule for `#{}`](issues/03-sigil-and-binding-rule.md): `~q`; a `%PlainSQL.Fragment{}` in `#{}` splices and any other value binds, decided at runtime by struct match; no modifiers in v1; sigil text is verbatim; the Empty Fragment is `parts: []`.
- [Portability statement and the closed divergence list](issues/04-portability-statement.md): a Dialect decides two things, the placeholder text for position N and the identifier delimiter pair; `{:list, values}` renders `(p1, ..., pn)` on every Dialect; Rendering never inspects a value, the Driver raises; an embedded delimiter in an identifier raises `ArgumentError`; SQLite uses `?`; README statement text fixed.
- [Dialect contract and Rendering output](issues/05-dialect-contract.md): `@behaviour PlainSQL.Dialect` with `placeholder/1` and `identifier_delimiters/0`; four modules ship under `PlainSQL.Dialect.*` (Postgres, SQLite, MySQL, MSSQL); `PlainSQL.render/2` returns `{sql :: String.t(), params :: list}` and raises; the Dialect module is explicit on every call, no defaults, no atoms; helpers and `render/2` live in `PlainSQL`.
- [Execution seam: render-only or a thin `query/2`](issues/07-execution-seam.md): in, as `PlainSQL.dialect/1` and `PlainSQL.query/3` in the core package; the Dialect comes from `DBConnection.connection_module/1` or `repo.__adapter__/0` through a closed four-row table; an atom that exports `__adapter__/0` is a repo, the repo path calls the injected `repo.query/3`; the Driver result and `opts` pass through untouched; the Tds row wraps params in `%Tds.Parameter{}`; inference failure raises `ArgumentError`, no override; `db_connection` and `ecto_sql` are optional deps.
- [Compile-time checks in the sigil](issues/08-compile-time-checks.md): two checks only, any modifier and an empty `#{}`, both raise `ArgumentError` from the macro (amends ticket 03's `CompileError`); no check on a string literal in `#{}`, no text inspection, no position checks, no strict mode.
- [Identifier binding and the raw-text escape hatch](issues/09-identifier-and-raw.md): `identifier/1` takes a binary and produces one `{:identifier, name}` part that Rendering always quotes, no composite form; `raw/1` takes a binary and produces one `{:text, binary}` part with a doc warning; `join/2` joins a list of Fragments with a separator Fragment and skips `nil`, `false`, and the Empty Fragment; all three live in `PlainSQL`.
- [Assemble the spec](issues/10-assemble-spec.md): written to `docs/spec.md`; six sections in the ticket's order plus an open-items section and a symbol-to-ticket appendix; every public symbol traces to a resolved ticket.

## Not yet specified

none. The destination is reached (2026-09-26).

## Out of scope

- Named bindings (`:id` style). `~q` binds by expression position, by [Sigil name and the Binding rule](issues/03-sigil-and-binding-rule.md). A named form is a new effort.
- Test strategy for Rendering per Dialect and the message text of each `ArgumentError`. The implementation effort decides them. `docs/spec.md` section 7 lists them.
- Connection pooling and wire protocols. Drivers own them.
- Transactions and streaming. Drivers and Ecto own them.
- Result-row mapping to structs. Every Driver has a different result shape.
- Compile-time schema validation (`sql.lock` style).
- `mix format` plugin for SQL text.
- Migrations.
- SQL transpiling: rewriting `LIMIT`/`TOP`, `RETURNING`, upsert, boolean literals, or any SQL text between Dialects. A Dialect changes how values and identifiers are bound, never what the SQL says.
- Forking or contributing to elixir-dbvisor/sql.
- `INSERT` and `UPDATE SET` builders from a map, and dynamic `ORDER BY` builders. Ruled out by the boundary rule of [Composition model](issues/02-composition-model.md): a helper never reads the text around it.
- Dialect-specific Fragments (a `dialect:` tag that makes Rendering under another Dialect raise). Ruled out by the statement of [Portability statement](issues/04-portability-statement.md): PlainSQL does not check that the SQL text is valid for the target database.
- A `~q` Fragment inside an Ecto `fragment/1`. Ruled out by [Execution seam](issues/07-execution-seam.md): it needs Ecto's `?` placeholder and a compile-time literal, which is macro work against `Ecto.Query`, not Rendering.
