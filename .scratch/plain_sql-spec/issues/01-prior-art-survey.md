# Prior art survey: composable SQL-as-text libraries

Type: research
Status: resolved
Blocked by: none

## Question

How do existing SQL-as-text libraries model Fragment Splicing, Binding, identifier binding, and Dialect rendering, and what do they say about portability?

Libraries to study from primary sources (source code and official docs):

- JS: `sql-template-tag`, `porsager/postgres` (nested template fragments, `sql()` helpers for identifiers and `IN` lists), `slonik`.
- Python: `sqlbind`.
- Rust: `sqlx::QueryBuilder`, `sea-query` (contrast: a DSL).
- Elixir: Ecto `fragment/1`, `ayesql` (SQL files with named params), elixir-dbvisor/sql at `/Volumes/Code/personal/sql`.
- Contrast case: `sqlglot` (full transpiling).

For each library, record:

1. The Fragment representation (text plus values, AST, or string).
2. How a Fragment splices into another and how bindings renumber.
3. How identifiers are bound and quoted.
4. How lists render for `IN` per database.
5. What the library promises about portability across databases, quoted from its docs.
6. Which recurring pains it solves with helpers (optional `WHERE`, joining conditions, empty Fragment).

## Blocks

02, 04

## Answer

Findings: [docs/research/prior-art-survey.md](../../../docs/research/prior-art-survey.md), commit `4ceaef1`.

Facts the blocked tickets rest on:

- Two Splicing designs exist. Design A assigns placeholder numbers at Rendering and needs no rewrite pass (sql-template-tag, porsager/postgres, sqlbind-t). Design B stores numbered placeholders and renumbers at Splicing (slonik, sea-query).
- Every library orders Bindings by text position. sqlbind ordered them by Binding time and documented the resulting mismatch.
- An empty Fragment is a first-class value in every library with optional clauses. Splicing it adds no text and no Bindings.
- Empty `AND`/`OR` join has three precedents: boolean literal (slonik `TRUE`/`FALSE`), omitted clause (sqlbind), raise (sql-template-tag `join([])`).
- `IN` is the one place surveyed libraries change SQL text per Dialect: `= ANY($1)` on Postgres, `IN (?, ?, ?)` elsewhere. `NOT IN` maps to `!= ALL($1)`, not `!= ANY($1)`; elixir-dbvisor/sql gets this wrong.
- SQLite caps bind parameters at 32766 (999 before 3.32.0). Per-element `IN` expansion has a ceiling there.
- Identifier Binding is quoting, not parameterisation, in every library. Postgres and SQLite use `"`, MySQL uses `` ` ``.
- No text-based library promises one SQL text runs on every database. sqlglot and sea-query rewrite SQL and call it best-effort.
- Rewriting `IN` from surrounding text needs grammar knowledge and breaks on casts (`in {{list}}::int4[]`). A helper that takes the list explicitly needs none.
