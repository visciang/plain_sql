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

## Not yet specified

- Named bindings (`:id`) versus positional bindings, and whether a Fragment may bind the same value twice.
- List and array values: where `IN` expansion ends and Driver type encoding begins (Postgres arrays, JSON).
- Dialect-specific Fragments: whether a Fragment can declare "Postgres only" and what Rendering does for another Dialect.
- Test strategy for Rendering per Dialect (golden files, property tests over Splicing).
- Ecto interop: a Fragment inside `Repo.query/2`, and whether an Ecto `fragment/1` bridge is wanted.
- Error surface: what a developer sees when a Binding is wrong (compile error, `ArgumentError` at Rendering, Dialect-specific message).
- Packaging: one hex package or core plus Dialect packages.

## Out of scope

- Connection pooling and wire protocols. Drivers own them.
- Transactions and streaming. Drivers and Ecto own them.
- Result-row mapping to structs. Every Driver has a different result shape.
- Compile-time schema validation (`sql.lock` style).
- `mix format` plugin for SQL text.
- Migrations.
- SQL transpiling: rewriting `LIMIT`/`TOP`, `RETURNING`, upsert, boolean literals, or any SQL text between Dialects. A Dialect changes how values and identifiers are bound, never what the SQL says.
- Forking or contributing to elixir-dbvisor/sql.
