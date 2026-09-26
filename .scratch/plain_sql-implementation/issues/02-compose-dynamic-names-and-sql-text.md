# 02: Compose dynamic names and SQL text

**Spec:** `docs/spec.md` section 2.4 (`identifier/1`, `raw/1`, `join/2`), section 2.6.

**What to build:** A developer builds an `INSERT` for a table and column list that is known only at runtime. `identifier/1` quotes each name for the Dialect. `join/2` places a separator between the column Fragments. `raw/1` splices SQL text read from a file. The result renders on all four Dialects with the correct delimiter pair.

**Blocked by:** 01 (Render bound and spliced Fragments).

**Status:** done

- [x] `identifier("users")` renders `"users"` on Postgres and SQLite, `` `users` `` on MySQL, and `[users]` on MSSQL.
- [x] `identifier/1` raises `ArgumentError` at the call for a non-binary and for `""`.
- [x] `identifier("public.users")` renders one quoted name. `~q"#{identifier("public")}.#{identifier("users")}"` renders two quoted names joined by `.`.
- [x] `render/2` raises `ArgumentError` for `identifier(~s|a"b|)` on Postgres and for `identifier("a]b")` on MSSQL. The same name renders on a Dialect whose delimiters it does not contain.
- [x] `raw(text)` produces one `{:text, text}` part. `raw("")` is the Empty Fragment.
- [x] `raw/1` raises `ArgumentError` at the call for a non-binary.
- [x] The `@doc` of `raw/1` carries the warning: "The text renders verbatim. Never pass text derived from user input."
- [x] `join(fragments, separator)` renders the members in order with the separator between them. A Binding inside the separator is repeated once per gap and numbered in text order.
- [x] `join/2` skips `nil`, `false`, and the Empty Fragment. It renders the Empty Fragment when no member remains.
- [x] `join/2` raises `ArgumentError` at the call for a member that is not a Fragment, `nil`, or `false`.
- [x] The `INSERT` idiom of spec 2.4 renders on all four Dialects.
