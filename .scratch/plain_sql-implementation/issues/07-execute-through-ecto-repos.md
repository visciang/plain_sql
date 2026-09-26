# 07: Execute through Ecto repos

**Spec:** `docs/spec.md` section 5.1 (repo rows and dispatch rule), 5.2 (repo path), 5.3.

**What to build:** A developer with an Ecto repo calls `PlainSQL.query(MyApp.Repo, fragment, opts)`. PlainSQL reads the adapter from the repo module, renders the Fragment, and calls the `repo.query/3` that `use Ecto.Adapters.SQL` injects. The call honours `put_dynamic_repo/1`. `PlainSQL.dialect(MyApp.Repo)` returns the Dialect module.

This ticket adds `ecto_sql` as an optional dep. The test suite runs a Postgres repo and a SQLite repo against the live databases of ticket 05.

**Blocked by:** 05 (Execute through Postgres and SQLite connections).

**Status:** done

- [x] An atom that exports `__adapter__/0` takes the repo path. Every other value takes the connection path.
- [x] `dialect(repo)` maps `Ecto.Adapters.Postgres`, `Ecto.Adapters.SQLite3`, `Ecto.Adapters.MyXQL`, and `Ecto.Adapters.Tds` to the four Dialect modules.
- [x] `dialect(repo)` raises `ArgumentError` for an adapter with no table row. The message names the adapter.
- [x] A repo pid is not a repo. `dialect(repo_pid)` follows the connection path and raises `ArgumentError` when `DBConnection.connection_module/1` returns `:error`.
- [x] `query(repo, fragment, opts)` calls `repo.query(sql, params, opts)` and returns the result untouched, both the `{:ok, _}` and the `{:error, _}` form.
- [x] `opts` reaches `repo.query/3` unchanged.
- [x] A test with two repo processes and `put_dynamic_repo/1` observes the query on the dynamic repo.
- [x] The Postgres repo and the SQLite repo each execute a Fragment with a Binding and a `list/1` part against the live database.
- [x] `mix compile --warnings-as-errors` is clean with `ecto_sql` absent from the deps.
- [x] The README documents the repo form of `query/3` and the dispatch rule.
