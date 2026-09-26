# Prior art survey: composable SQL-as-text libraries

Type: research
Status: open
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
