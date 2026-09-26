# 01: Render bound and spliced Fragments

**Spec:** `docs/spec.md` sections 1, 2.1, 2.2, 2.3, 2.5, 3, 4.

**What to build:** A developer adds `plain_sql` to a Mix project, writes `import PlainSQL`, composes a query with `~q` and `#{}`, and calls `render/2` with one of the four shipped Dialect modules. The call returns the SQL string and the ordered value list. A Fragment inside `#{}` splices. Any other value binds. The same query renders on Postgres, SQLite, MySQL, and MSSQL with only the placeholder text changed.

This ticket creates the Mix project. It ships the `PlainSQL.Fragment` struct, the `~q` macro, the `PlainSQL.Dialect` behaviour, the four Dialect modules, and `render/2`. It ships no helper.

**Blocked by:** None (can start immediately).

**Status:** done

- [x] `mix new plain_sql` layout exists with `mix test` green and `mix compile --warnings-as-errors` clean.
- [x] `PlainSQL.Fragment` holds the struct and the `part` type from spec 2.1 and no function.
- [x] `~q"SELECT * FROM t WHERE id = #{1}"` renders `{"SELECT * FROM t WHERE id = $1", [1]}` on Postgres and `{"SELECT * FROM t WHERE id = ?", [1]}` on SQLite.
- [x] A `%PlainSQL.Fragment{}` in `#{}` splices its parts at that position. A Fragment in a variable and a Fragment written inline produce identical parts.
- [x] A string, a list, a map, `nil`, `%Date{}`, and `%Decimal{}` in `#{}` each bind as one `{:binding, value}` part with the value unchanged.
- [x] Bindings are numbered in text order. A Fragment spliced twice contributes its Bindings twice with distinct placeholders.
- [x] `~q""` produces `%PlainSQL.Fragment{parts: []}`. Splicing it adds no text and no Bindings. `render/2` returns `{"", []}` for it.
- [x] The macro drops `{:text, ""}` parts.
- [x] Sigil text is verbatim: `\n` stays two characters, `\"` becomes `"`, `~q|...|` works, `~q"""` strips indentation.
- [x] Any modifier on `~q` raises `ArgumentError` at compile time.
- [x] An empty `#{}` in `~q` raises `ArgumentError` at compile time.
- [x] `PlainSQL.Dialect` defines `placeholder/1` and `identifier_delimiters/0` as callbacks and nothing else. Its moduledoc carries the skeleton from spec 3.3.
- [x] `PlainSQL.Dialect.Postgres`, `SQLite`, `MySQL`, and `MSSQL` return the values of the table in spec 3.2.
- [x] `render/2` takes the Dialect module explicitly. There is no `render/1`, no default, and no atom shorthand.
- [x] `render/2` renders `{:identifier, name}` parts with the delimiter pair and `{:list, values}` parts as `(p1, ..., pn)` per the table in spec 2.5, so tickets 02 and 04 add no Rendering clause.
- [x] `render/2` raises `ArgumentError` when an identifier name contains the open or the close delimiter of the Dialect.
- [x] Every raise is `ArgumentError`. The test suite does not assert message text.
- [x] The README contains the portability statement of spec 1 verbatim and the `'#{name}'` quoted-literal warning of spec 4.
