# Dialect inference from a connection or repo

Ticket: `.scratch/plain_sql-spec/issues/06-dialect-inference.md`.
Date: 2026-09-26.
Sources: library source code and hexdocs. Each claim cites its source. Remote sources are the `master` or `main` branch on the date above, except where a tag is named. `db_connection` 2.10.2 and `exqlite` 0.41.0 were read from local Hex copies and cited at their GitHub tags.

Terms follow `CONTEXT.md`: Dialect, Driver, Rendering. Library-specific names appear in backticks. `Ecto.Adapters.Postgres` and similar names are Ecto module names, not PlainSQL terms.

Question: a caller holds a live connection pid, a `DBConnection` handle, or an Ecto repo module. Can the caller discover the Driver, and so the Dialect, without configuration?

Short answer: yes, for every Driver in scope. `DBConnection.connection_module/1` is a public function. It returns the Driver connection module for a pool pid, a pool name, or a `%DBConnection{}` handle. `repo.__adapter__/0` and `Ecto.Adapter.lookup_meta/1` are public functions. They return the Ecto adapter module and the Ecto connection module for a repo. No Driver exposes its placeholder style as a function or a documented constant.

Verification: the DBConnection and Exqlite claims marked "verified" were run on 2026-09-26 against an in-memory Exqlite pool with `db_connection` 2.10.2 and `exqlite` 0.41.0. All other claims come from reading the source.

## DBConnection

Handle types. `DBConnection.conn()` is `GenServer.server() | %DBConnection{}` (`lib/db_connection.ex`, `@type conn`, <https://github.com/elixir-ecto/db_connection/blob/v2.10.2/lib/db_connection.ex>). `GenServer.server()` covers the pool pid returned by `start_link`, a registered name, and a `{:via, _, _}` tuple. `%DBConnection{}` is the handle that `run/3` and `transaction/3` pass to the callback. The struct has the fields `pool_ref`, `conn_ref`, and `conn_mode` (`defstruct [:pool_ref, :conn_ref, :conn_mode]`, same file).

What `start_link` registers. `DBConnection.start_link(conn_mod, opts)` calls `child_spec/2`. `child_spec/2` reads the `:pool` option, default `DBConnection.ConnectionPool`, and calls `pool.child_spec({conn_mod, opts})` (`lib/db_connection.ex`, `start_link/2`, `child_spec/2`). The pool process stores the connection module in its process dictionary. `DBConnection.ConnectionPool.init/1` calls `DBConnection.register_as_pool(mod)` (`lib/db_connection/connection_pool.ex`, `init/1`, <https://github.com/elixir-ecto/db_connection/blob/v2.10.2/lib/db_connection/connection_pool.ex>). `DBConnection.Ownership.Manager.init/1` does the same (`lib/db_connection/ownership/manager.ex`, `init/1`). `register_as_pool/1` is `@doc false` and runs `Process.put(:connection_module, conn_module)` (`lib/db_connection.ex`, `@connection_module_key :connection_module`, `register_as_pool/1`).

Public discovery call. `DBConnection.connection_module(conn) :: {:ok, module} | :error` (`lib/db_connection.ex`, `connection_module/1`; hexdocs <https://hexdocs.pm/db_connection/DBConnection.html#connection_module/1>). The doc states: "Returns the connection module used by the given connection pool. When given a process that is not a connection pool, returns an `:error`." The function accepts the full `conn` type. For a `%DBConnection{}` it reads the pool pid from `pool_ref`. For any other value it calls `GenServer.whereis/1`. It then reads `Process.info(pid, :dictionary)` and looks up the `:connection_module` key (`lib/db_connection.ex`, `connection_module/1`, `pool_pid/1`). The CHANGELOG lists the function under v2.4.2, 2022-03-03 (`CHANGELOG.md`, <https://github.com/elixir-ecto/db_connection/blob/v2.10.2/CHANGELOG.md>).

Verified: `DBConnection.connection_module(pool_pid)` returned `{:ok, Exqlite.Connection}`. Inside `DBConnection.run/3`, `DBConnection.connection_module(%DBConnection{})` returned `{:ok, Exqlite.Connection}`. `DBConnection.connection_module(self())` on a non-pool process returned `:error`.

`Process.info(pid, :dictionary)`. This is the mechanism behind the public function. The key is `:connection_module`. Verified: `List.keyfind(dictionary, :connection_module, 0)` returned `{:connection_module, Exqlite.Connection}`. The key name is a module attribute, not a documented contract. Use `connection_module/1` instead.

`:sys.get_state/1` on the pool. `DBConnection.ConnectionPool.init/1` returns the state `{:busy, queue, codel, ts}` (`lib/db_connection/connection_pool.ex`, `init/1`). `queue` is an ETS table id. `codel` is a map of timing values. The state does not contain the connection module. Verified: `:sys.get_state(pool_pid)` returned a 4-tuple with first element `:busy`. This path does not give the Driver.

Other private paths. The connection module also sits in two private places. The `DBConnection.Holder` ETS record `conn` has a `module` field (`lib/db_connection/holder.ex`, `Record.defrecord(:conn, [:connection, :module, :state, ...])`, <https://github.com/elixir-ecto/db_connection/blob/v2.10.2/lib/db_connection/holder.ex>). `DBConnection.Holder` is `@moduledoc false`. Each connection process is a `:gen_statem` with data `%{mod: mod, ...}` (`lib/db_connection/connection.ex`, `init/1`, <https://github.com/elixir-ecto/db_connection/blob/v2.10.2/lib/db_connection/connection.ex>). `DBConnection.Connection` is `@moduledoc false`. The caller does not hold a connection pid. `start_link` returns the pool pid.

Limits. Only pools that call `register_as_pool/1` support `connection_module/1`. The two built-in pools do. A custom `:pool` module may not. A `PartitionSupervisor` pid is not a pool pid. The supervisor dictionary has no `:connection_module` key. `connection_module/1` returns `:error` for it (derived from `connection_module/1`, not run). A `{:via, PartitionSupervisor, {name, key}}` tuple resolves to one partition pool through `GenServer.whereis/1`. `connection_module/1` works for that form (derived from `pool_pid/1`, not run).

## Postgrex

Handle type. `Postgrex.conn()` is `DBConnection.conn()` (`lib/postgrex.ex`, `@type conn`, <https://github.com/elixir-ecto/postgrex/blob/master/lib/postgrex.ex>).

Registration. `Postgrex.start_link/1` calls `DBConnection.start_link(Postgrex.Protocol, opts)`. `Postgrex.child_spec/1` calls `DBConnection.child_spec(Postgrex.Protocol, opts)` (`lib/postgrex.ex`, `start_link/1`, `child_spec/1`).

Public discovery call. `DBConnection.connection_module(conn)` returns `{:ok, Postgrex.Protocol}` for a Postgrex pool or handle (derived from the registration above and the DBConnection section). Postgrex has no function of its own for this.

Private discovery path. Same as DBConnection. `Postgrex.Protocol` is the `mod` in the connection `:gen_statem` data and in the Holder record.

Placeholder style. `$1`, `$2`, ... The `query/4` doc states: "If using the extended query protocol, parameters can be set as `$1` embedded in the query string" and "If using the simple query protocol, queries cannot be parameterized" (`lib/postgrex.ex`, `query/4` doc). The `:query_type` option selects `:binary` (extended, default) or `:text` (simple). No function or constant exposes the placeholder style.

Accepts `{sql, params}` call. No. `Postgrex.query(conn, statement, params, opts)` takes the statement and the params as separate arguments. The spec is `query(conn, iodata, list, [query_option])` (`lib/postgrex.ex`, `@spec query`). The guard requires `is_list(params)`.

## Exqlite

Handle types. `Exqlite.start_link/1` returns a DBConnection pool pid. The functions in `Exqlite` take `DBConnection.conn()` (`lib/exqlite.ex`, `@spec query`, <https://github.com/elixir-sqlite/exqlite/blob/v0.41.0/lib/exqlite.ex>). Exqlite also has a lower API. `Exqlite.Sqlite3.open/2` returns `{:ok, db}` where `db` is a `reference()` (`lib/exqlite/sqlite3.ex`, `@type db() :: reference()`, <https://github.com/elixir-sqlite/exqlite/blob/v0.41.0/lib/exqlite/sqlite3.ex>). A NIF reference carries no module. A caller with a bare `db` reference has no discovery call.

Registration. `Exqlite.start_link/1` calls `DBConnection.start_link(Connection, opts)` where `Connection` is `Exqlite.Connection`. `Exqlite.child_spec/1` calls `DBConnection.child_spec(Connection, opts)` (`lib/exqlite.ex`, `start_link/1`, `child_spec/1`).

Public discovery call. `DBConnection.connection_module(conn)` returns `{:ok, Exqlite.Connection}`. Verified.

Private discovery path. Same as DBConnection. `Exqlite.Connection` state is a struct with `db`, `path`, `transaction_status`, and similar fields (`lib/exqlite/connection.ex`, `defstruct`, <https://github.com/elixir-sqlite/exqlite/blob/v0.41.0/lib/exqlite/connection.ex>). The struct name identifies the Driver. The caller does not hold that process.

Placeholder style. SQLite accepts `?`, `?NNN`, `:AAA`, `@AAA`, and `$AAA` (SQLite documentation, <https://sqlite.org/lang_expr.html#varparam>). `Exqlite.Sqlite3.bind/2` binds a list positionally and a map by name. The doctests show `SELECT ?, ?, ?, ?, ?` with a list and `SELECT :42, @pi, $name, @blob, :null` with a map (`lib/exqlite/sqlite3.ex`, `bind/2` doc). Verified: `Exqlite.query!(pid, "SELECT ?1, ?2", [1, 2])` and `Exqlite.query!(pid, "SELECT ?, ?", [1, 2])` both returned `[[1, 2]]`. No function or constant exposes the placeholder style.

Accepts `{sql, params}` call. No. `Exqlite.query(conn, statement, params, opts)` takes separate arguments. The spec is `query(DBConnection.conn(), iodata(), list(), list())` (`lib/exqlite.ex`, `@spec query`).

## ecto_sqlite3

Handle type. An Ecto repo module or repo pid. See the Ecto section.

Registration. `Ecto.Adapters.SQLite3` is `use Ecto.Adapters.SQL, driver: :exqlite` (`lib/ecto/adapters/sqlite3.ex`, <https://github.com/elixir-sqlite/ecto_sqlite3/blob/main/lib/ecto/adapters/sqlite3.ex>). `Ecto.Adapters.SQLite3.Connection.child_spec/1` calls `DBConnection.child_spec(Exqlite.Connection, options)` directly (`lib/ecto/adapters/sqlite3/connection.ex`, `child_spec/1`, <https://github.com/elixir-sqlite/ecto_sqlite3/blob/main/lib/ecto/adapters/sqlite3/connection.ex>). The pool pid in the repo meta is a DBConnection pool for `Exqlite.Connection`.

Public discovery calls. `repo.__adapter__()` returns `Ecto.Adapters.SQLite3`. `Ecto.Adapter.lookup_meta(repo).sql` returns `Ecto.Adapters.SQLite3.Connection`. `DBConnection.connection_module(Ecto.Adapter.lookup_meta(repo).pid)` returns `{:ok, Exqlite.Connection}` (derived from the registration above and the Ecto section).

Placeholder style. The Rendering of a bound value `{:^, [], [ix]}` is `?` (`lib/ecto/adapters/sqlite3/connection.ex`, `defp expr({:^, [], [_ix]}, _sources, _query), do: ~c"?"`). `insert_each/2` renders `?N` with a running counter (same file, `insert_each/2`). `table_exists_query/1` uses `?` (same file). These are private functions of a `@moduledoc false` module.

Accepts `{sql, params}` call. `Ecto.Adapters.SQLite3.Connection.query(conn, sql, params, options)` builds an `Exqlite.Query` and calls `DBConnection.execute/4` (same file, `query/4`). It takes separate arguments. See the Ecto section for `Ecto.Adapters.SQL.query/4`.

## MyXQL

Handle type. `MyXQL.conn()` is `DBConnection.conn()` (`lib/myxql.ex`, `@type conn()`, <https://github.com/elixir-ecto/myxql/blob/master/lib/myxql.ex>).

Registration. `MyXQL.start_link/1` calls `DBConnection.start_link(MyXQL.Connection, options)`. `MyXQL.child_spec/1` calls `DBConnection.child_spec(MyXQL.Connection, options)` (`lib/myxql.ex`, `start_link/1`, `child_spec/1`).

Public discovery call. `DBConnection.connection_module(conn)` returns `{:ok, MyXQL.Connection}` (derived). MyXQL has no function of its own for this.

Private discovery path. Same as DBConnection.

Placeholder style. `?`. The `query/4` doc example is `MyXQL.query(conn, "INSERT INTO posts (title) VALUES (?)", ["title 2"])` (`lib/myxql.ex`, `query/4` doc). Placeholders belong to the binary protocol. The doc states for the binary protocol: "The query statement is still sent as text, however it may contain placeholders for parameter values" (`lib/myxql.ex`, `query/4` doc, section "Text queries and prepared statements"). The `:query_type` option selects `:binary` (default), `:binary_then_text`, or `:text`. No function or constant exposes the placeholder style.

Accepts `{sql, params}` call. No. `MyXQL.query(conn, statement, params, options)` takes separate arguments. The spec is `query(conn, iodata, list, [query_option()])` (`lib/myxql.ex`, `@spec query`).

## Tds

The repository moved. `https://github.com/livehelpnow/tds` redirects to `https://github.com/elixir-ecto/tds`. The README states `git clone https://github.com/elixir-ecto/tds.git` (`README.md`, section Contributing, <https://github.com/elixir-ecto/tds/blob/master/README.md>).

Handle type. `Tds.conn()` is `DBConnection.conn()` (`lib/tds.ex`, `@type conn`, <https://github.com/elixir-ecto/tds/blob/master/lib/tds.ex>).

Registration. `Tds.start_link/1` calls `DBConnection.start_link(Tds.Protocol, default(opts))`. `Tds.child_spec/1` calls `DBConnection.child_spec(Tds.Protocol, default(opts))` (`lib/tds.ex`, `start_link/1`, `child_spec/1`).

Public discovery call. `DBConnection.connection_module(conn)` returns `{:ok, Tds.Protocol}` (derived). Tds has no function of its own for this.

Private discovery path. Same as DBConnection. The `Tds.Protocol` state is a struct with `sock`, `opts`, `state`, `transaction`, and `env` fields (`lib/tds/protocol.ex`, `defstruct`, <https://github.com/elixir-ecto/tds/blob/master/lib/tds/protocol.ex>).

Placeholder style. `@name`. The README example is `Tds.query!(pid, "INSERT INTO MyTable (MyColumn) VALUES (@my_value)", [%Tds.Parameter{name: "@my_value", value: "My Actual Value"}])` (`README.md`, section Usage). A plain value list also works. `Tds.Protocol.send_param_query/3` calls `Tds.Parameter.prepare_params(params)` (`lib/tds/protocol.ex`, `send_param_query/3`). `prepare_params/1` names each raw value `@1`, `@2`, ... in list order (`lib/tds/parameter.ex`, `prepare_params/1`, `do_name/3`, `fix_data_type/2`, <https://github.com/elixir-ecto/tds/blob/master/lib/tds/parameter.ex>). `Tds.Parameter` is `@moduledoc false`. The `@1..@n` naming of a plain list is an implementation detail. The `@name` form with `%Tds.Parameter{}` is the documented form. No function or constant exposes the placeholder style.

Accepts `{sql, params}` call. No. `Tds.query(conn, statement, params, opts)` takes separate arguments. The spec is `query(conn, iodata, list, [execute_option])` (`lib/tds.ex`, `@spec query`). `params` has no default value in `Tds.query/4`.

## Ecto and ecto_sql

Handle types. A repo module, a repo name atom, or a repo pid. `Ecto.Adapters.SQL.query/4` accepts `pid() | Ecto.Repo.t() | Ecto.Adapter.adapter_meta()` (`lib/ecto/adapters/sql.ex`, `@spec query`, <https://github.com/elixir-ecto/ecto_sql/blob/master/lib/ecto/adapters/sql.ex>). The pid is the repo supervisor pid. `Ecto.Repo.Registry` stores the meta under that pid (`lib/ecto/repo/supervisor.ex`, `start_child/4`, `Ecto.Repo.Registry.associate(self(), name, meta)`, <https://github.com/elixir-ecto/ecto/blob/master/lib/ecto/repo/supervisor.ex>).

Public discovery call 1: `repo.__adapter__/0`. `Ecto.Repo` declares `@callback __adapter__ :: Ecto.Adapter.t()` with the doc "Returns the adapter tied to the repository" (`lib/ecto/repo.ex`, <https://github.com/elixir-ecto/ecto/blob/master/lib/ecto/repo.ex>). `use Ecto.Repo` generates `def __adapter__, do: @adapter`. `@adapter` comes from the `:adapter` option of `use Ecto.Repo` through `Ecto.Repo.Supervisor.compile_config/2` (`lib/ecto/repo.ex`, `__using__/1`; `lib/ecto/repo/supervisor.ex`, `compile_config/2`). The value is fixed at compile time. It does not need a running repo. The `:adapter` option is configuration of the repo module. PlainSQL does not add configuration. The mapping from adapter module to Driver and Dialect is:

| `repo.__adapter__()` | Ecto connection module (`meta.sql`) | Driver connection module | Dialect |
| --- | --- | --- | --- |
| `Ecto.Adapters.Postgres` | `Ecto.Adapters.Postgres.Connection` | `Postgrex.Protocol` | PostgreSQL |
| `Ecto.Adapters.SQLite3` | `Ecto.Adapters.SQLite3.Connection` | `Exqlite.Connection` | SQLite |
| `Ecto.Adapters.MyXQL` | `Ecto.Adapters.MyXQL.Connection` | `MyXQL.Connection` | MySQL |
| `Ecto.Adapters.Tds` | `Ecto.Adapters.Tds.Connection` | `Tds.Protocol` | SQL Server |

Sources for the table: `Ecto.Adapters.SQL.__using__/1` sets `@conn __MODULE__.Connection` (`lib/ecto/adapters/sql.ex`). Each `Connection.child_spec/1` calls the Driver: `Postgrex.child_spec/1` (`lib/ecto/adapters/postgres/connection.ex`), `MyXQL.child_spec/1` (`lib/ecto/adapters/myxql/connection.ex`), `Tds.child_spec/1` (`lib/ecto/adapters/tds/connection.ex`), and `DBConnection.child_spec(Exqlite.Connection, _)` (`ecto_sqlite3`, `lib/ecto/adapters/sqlite3/connection.ex`).

Public discovery call 2: `Ecto.Adapter.lookup_meta/1`. The doc states "Returns the adapter metadata from its `c:init/1` callback. It expects a process name of a repository. The name is either an atom or a PID" (`lib/ecto/adapter.ex`, `lookup_meta/1`, <https://github.com/elixir-ecto/ecto/blob/master/lib/ecto/adapter.ex>). The doc recommends `Ecto.Adapter.lookup_meta(repo.get_dynamic_repo())`. The call needs a running repo. The meta map for a SQL adapter has these keys: `:sql` (the Ecto connection module), `:pid` (the pool pid), `:telemetry`, `:opts`, `:stacktrace`, `:log_stacktrace_mfa` from `Ecto.Adapters.SQL.init/3`; `:repo` and `:cache` from `Ecto.Repo.Supervisor.init/1`; `:adapter` and `:pid` from `Ecto.Repo.Supervisor.start_child/4` (`lib/ecto/adapters/sql.ex`, `init/3`; `lib/ecto/repo/supervisor.ex`, `init/1`, `start_child/4`). `Ecto.Adapter.adapter_meta` is typed as `%{optional(:stacktrace) => boolean(), optional(any()) => any()}` (`lib/ecto/adapter.ex`). The documented keys are `:cache` and `:pid`. The `:sql` and `:adapter` keys are set by the code but not listed in the type doc. With `pool_count > 1`, `:pid` is a `PartitionSupervisor` pid and the meta gains `:partition_supervisor` (`lib/ecto/adapters/sql.ex`, `init/3`).

Public discovery call 3: `DBConnection.connection_module(meta.pid)`. For `pool_count: 1` this returns the Driver connection module (derived from the DBConnection section).

`Ecto.Adapters.SQL.to_sql/3`. The spec is `to_sql(:all | :update_all | :delete_all, Ecto.Repo.t(), Ecto.Queryable.t(), Keyword.t()) :: {String.t(), query_params}` (`lib/ecto/adapters/sql.ex`, `@spec to_sql`). It produces a `{sql, params}` tuple from an `Ecto.Query`. It does not accept one. Its output is the Rendering of an Ecto query for the repo adapter. The doc example shows `{"UPDATE posts AS p SET title = $1", ["hello"]}` for Postgres (`lib/ecto/adapters/sql.ex`, `@to_sql_doc`).

`Ecto.Adapters.SQL.query/4`. The signature is `query(repo, sql, params \\ [], opts \\ [])`. `sql` is `iodata`. `params` is `query_params :: [term] | %{(atom | String.t()) => term}` (`lib/ecto/adapters/sql.ex`, `@type query_params`, `@spec query`). It takes separate arguments. No public function in `Ecto.Adapters.SQL` accepts a `{sql, params}` tuple. The built-in connection modules reject a map: `ensure_list_params!/1` raises `ArgumentError` for a non-list in `Ecto.Adapters.Postgres.Connection`, `Ecto.Adapters.MyXQL.Connection`, and `Ecto.Adapters.Tds.Connection` (`lib/ecto/adapters/postgres/connection.ex`, `lib/ecto/adapters/myxql/connection.ex`, `lib/ecto/adapters/tds/connection.ex`, `query/4`). `query/4` resolves the repo through `Ecto.Adapter.lookup_meta/1` and then calls `apply(meta.sql, :query, [conn, sql, params, opts])` (`lib/ecto/adapters/sql.ex`, `query/4`, `sql_call/5`). `conn` is the checked-out `%DBConnection{}` from the process dictionary, or the pool (`get_conn_or_pool/2`, same file). `use Ecto.Adapters.SQL` also injects `query/3` and `to_sql/2` into the repo module (`lib/ecto/adapters/sql.ex`, `__before_compile__/2`).

Placeholder style in the Ecto connection modules. `Ecto.Adapters.SQL.Connection` has no callback for the placeholder style. Its callbacks are `child_spec`, `prepare_execute`, `execute`, `query`, `query_many`, `read_only_transaction`, `stream`, `to_constraints`, `all`, `update_all`, `delete_all`, `insert`, `update`, `delete`, `explain_query`, `execute_ddl`, `ddl_logs`, and `table_exists_query` (`lib/ecto/adapters/sql/connection.ex`, <https://github.com/elixir-ecto/ecto_sql/blob/master/lib/ecto/adapters/sql/connection.ex>). Each module renders `{:^, [], [ix]}` in a private `expr/3` clause:

| Module | `expr({:^, [], [ix]}, ...)` | Source |
| --- | --- | --- |
| `Ecto.Adapters.Postgres.Connection` | `[?$ \| Integer.to_string(ix + 1)]` → `$1` | `lib/ecto/adapters/postgres/connection.ex` |
| `Ecto.Adapters.MyXQL.Connection` | `~c"?"` → `?` | `lib/ecto/adapters/myxql/connection.ex` |
| `Ecto.Adapters.Tds.Connection` | `"@#{idx + 1}"` → `@1` | `lib/ecto/adapters/tds/connection.ex` |
| `Ecto.Adapters.SQLite3.Connection` | `~c"?"` → `?` | `ecto_sqlite3`, `lib/ecto/adapters/sqlite3/connection.ex` |

All four modules are `@moduledoc false`. `Ecto.Adapters.Tds.Connection.prepare_params/1` is a public `def`. It wraps each raw value in `%Tds.Parameter{name: "@#{acc}"}` in list order (`lib/ecto/adapters/tds/connection.ex`, `prepare_params/1`). The `table_exists_query/1` callback returns `{sql, params}` with the module placeholder style: `$1` for Postgres, `?` for MyXQL and SQLite3, `@1` for Tds (each `connection.ex`, `table_exists_query/1`). This is a callback of `Ecto.Adapters.SQL.Connection`. It is the only public function that shows the placeholder style of an Ecto connection module in its output. Its purpose is a table check, not a placeholder query.

## Summary table

| Driver | Handle type | Public discovery call | Private discovery path | Placeholder style | Accepts `{sql, params}` call |
| --- | --- | --- | --- | --- | --- |
| Postgrex | `DBConnection.conn()`: pool pid, name, or `%DBConnection{}` | `DBConnection.connection_module(conn)` → `{:ok, Postgrex.Protocol}` | pool dictionary key `:connection_module`; Holder ETS `conn(module:)`; connection `:gen_statem` data `%{mod:}` | `$1`, extended protocol only | none exists; `Postgrex.query(conn, sql, params, opts)` |
| Exqlite | `DBConnection.conn()`; or a bare `Exqlite.Sqlite3.db()` reference | `DBConnection.connection_module(conn)` → `{:ok, Exqlite.Connection}` (verified); none exists for a bare `db` reference | same as Postgrex | `?`, `?NNN`, `:AAA`, `@AAA`, `$AAA` (SQLite) | none exists; `Exqlite.query(conn, sql, params, opts)` |
| ecto_sqlite3 | repo module, name, or pid | `repo.__adapter__()` → `Ecto.Adapters.SQLite3`; `Ecto.Adapter.lookup_meta(repo).sql` → `Ecto.Adapters.SQLite3.Connection`; `DBConnection.connection_module(meta.pid)` → `{:ok, Exqlite.Connection}` | `meta.sql`, `meta.adapter` are undocumented keys | `?` for `^`; `?N` in `insert_each/2` | none exists; `Ecto.Adapters.SQL.query(repo, sql, params, opts)` |
| MyXQL | `DBConnection.conn()` | `DBConnection.connection_module(conn)` → `{:ok, MyXQL.Connection}` | same as Postgrex | `?`, binary protocol only | none exists; `MyXQL.query(conn, sql, params, opts)` |
| Tds | `DBConnection.conn()` | `DBConnection.connection_module(conn)` → `{:ok, Tds.Protocol}` | same as Postgrex | `@name` with `%Tds.Parameter{}`; plain list gets `@1..@n` (private) | none exists; `Tds.query(conn, sql, params, opts)` |
| Ecto (`ecto_sql`) | repo module, name, or pid; `adapter_meta` map | `repo.__adapter__()`; `Ecto.Adapter.lookup_meta(repo)` | `meta.sql`, `meta.adapter`, `meta.pid` are set by code; only `:cache` and `:pid` are documented | per connection module: `$1`, `?`, `@1`, `?` | none exists; `Ecto.Adapters.SQL.query(repo, sql, params, opts)`; `to_sql/3` returns `{sql, params}` |
| DBConnection | `GenServer.server() \| %DBConnection{}` | `DBConnection.connection_module(conn)` since v2.4.2 (verified) | `Process.info(pool, :dictionary)` key `:connection_module`; `:sys.get_state(pool)` gives `{:busy \| :ready, ets, codel, ts}` without the module | not applicable | not applicable; `DBConnection.execute(conn, %Query{}, params, opts)` |

## Findings relevant to ticket 07

1. A `PlainSQL.query(conn_or_repo, fragment)` function can select the Dialect without configuration. For a `DBConnection.conn()` the call is `DBConnection.connection_module(conn)`. It returns `{:ok, Postgrex.Protocol}`, `{:ok, Exqlite.Connection}`, `{:ok, MyXQL.Connection}`, or `{:ok, Tds.Protocol}`. For an Ecto repo the call is `repo.__adapter__()`. It returns `Ecto.Adapters.Postgres`, `Ecto.Adapters.SQLite3`, `Ecto.Adapters.MyXQL`, or `Ecto.Adapters.Tds`. Both calls are public and documented. Sources: DBConnection and Ecto sections.

2. `DBConnection.connection_module/1` works on the `%DBConnection{}` handle inside `run/3` and `transaction/3`. Verified with Exqlite. A `PlainSQL.query/2` inside a transaction callback needs no extra argument.

3. The map from Driver connection module to Dialect is a fixed table of four entries. PlainSQL must own that table. No Driver, and no Ecto module, exposes its placeholder style as a function or a documented constant. The Rendering clauses in the Ecto connection modules are private (`defp expr({:^, [], [ix]}, ...)`). Sources: each Driver section, "Placeholder style".

4. `DBConnection.connection_module/1` returns `:error` for a process that is not a built-in pool. Cases: a custom `:pool` module that does not call `register_as_pool/1`, a `PartitionSupervisor` pid from an Ecto repo with `pool_count > 1`, and any non-pool pid. Verified for a non-pool pid. `PlainSQL.query/2` needs an explicit Dialect argument or an error return for these cases.

5. `repo.__adapter__/0` is a compile-time value. It does not need a running repo. `Ecto.Adapter.lookup_meta/1` needs a running repo. For a stopped repo, `Ecto.Repo.Registry.lookup/1` raises "could not lookup Ecto repo ... because it was not started". For Dialect selection from a repo module, `__adapter__/0` is the cheaper and safer call.

6. Every Driver `query` function takes `sql` and `params` as two arguments: `Postgrex.query/4`, `Exqlite.query/4`, `MyXQL.query/4`, `Tds.query/4`, and `Ecto.Adapters.SQL.query/4`. None accepts a `{sql, params}` tuple. A PlainSQL execution seam must destructure its Rendering result before the Driver call. `Ecto.Adapters.SQL.to_sql/3` is the existing precedent for a `{sql, params}` return value.

7. The Ecto path does not need the Driver module. `Ecto.Adapters.SQL.query(repo, sql, params, opts)` resolves the pool, the connection module, telemetry, and logging from the repo meta. A PlainSQL Ecto seam can call it directly after Rendering. It selects the Dialect from `repo.__adapter__()`. It does not need `DBConnection`.

8. Tds needs a param shape decision. `Tds.query/4` accepts a plain value list and names the values `@1..@n` in list order through `Tds.Parameter.prepare_params/1`. That module is `@moduledoc false`. The documented form is a `%Tds.Parameter{name: "@name"}` list. `Ecto.Adapters.Tds.Connection.prepare_params/1` is a public `def` that produces the `@1..@n` form. A SQL Server Dialect can render `@1..@n` and pass a plain list. That design depends on the private naming rule or on the Ecto function.
