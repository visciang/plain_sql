defmodule PlainSQL.RepoTest do
  use ExUnit.Case, async: true

  import PlainSQL

  alias PlainSQL.Dialect.MSSQL
  alias PlainSQL.Dialect.MySQL
  alias PlainSQL.Dialect.Postgres
  alias PlainSQL.Dialect.SQLite
  alias PlainSQL.TestSupport.MSSQLRepo
  alias PlainSQL.TestSupport.MySQLRepo
  alias PlainSQL.TestSupport.PostgresRepo
  alias PlainSQL.TestSupport.SQLiteRepo
  alias PlainSQL.TestSupport.UnknownAdapterRepo

  defp start_sqlite_repo(opts \\ []) do
    start_supervised!(
      {SQLiteRepo, [database: ":memory:", pool_size: 1, log: false] ++ opts},
      id: make_ref()
    )
  end

  defp start_postgres_repo do
    start_supervised!(
      {PostgresRepo, [url: System.fetch_env!("PG_URL"), pool_size: 1, log: false]}
    )
  end

  describe "dialect/1 with a repo" do
    test "an atom that exports __adapter__/0 takes the repo path" do
      assert dialect(PostgresRepo) == Postgres
      assert dialect(SQLiteRepo) == SQLite
      assert dialect(MySQLRepo) == MySQL
      assert dialect(MSSQLRepo) == MSSQL
    end

    test "raises ArgumentError naming the adapter for an adapter with no table row" do
      error = assert_raise ArgumentError, fn -> dialect(UnknownAdapterRepo) end
      assert error.message =~ "Ecto.Adapters.Unknown"
    end

    test "a repo pid takes the connection path and is not a pool" do
      pid = start_sqlite_repo()

      error = assert_raise ArgumentError, fn -> dialect(pid) end
      assert error.message =~ inspect(pid)
    end
  end

  describe "query/3 with a SQLite repo" do
    setup do
      start_sqlite_repo()
      SQLiteRepo.query!("CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT)")
      SQLiteRepo.query!("INSERT INTO t (id, name) VALUES (1, 'a'), (2, 'b'), (3, 'c')")
      :ok
    end

    test "returns the repo.query/3 result untouched" do
      assert {:ok, %Exqlite.Result{rows: [[2, "b"], [3, "c"]]}} =
               query(
                 SQLiteRepo,
                 ~q"SELECT id, name FROM t WHERE id IN #{list([2, 3])} AND id > #{1}"
               )

      assert {:error, %Exqlite.Error{}} =
               query(SQLiteRepo, ~q"SELECT * FROM missing WHERE id = #{1}")
    end

    test "opts reach repo.query/3 unchanged" do
      # The `:options` metadata of the query event is `opts[:telemetry_options]`.
      ref = make_ref()
      event = SQLiteRepo.config()[:telemetry_prefix] ++ [:query]
      :telemetry.attach(ref, event, &__MODULE__.forward_metadata/4, self())
      on_exit(fn -> :telemetry.detach(ref) end)

      query(SQLiteRepo, ~q"SELECT 1", telemetry_options: [marker: ref])

      assert_receive {:metadata, %{options: [marker: ^ref]}}
    end

    def forward_metadata(_event, _measurements, metadata, test_pid) do
      send(test_pid, {:metadata, metadata})
    end

    test "honours put_dynamic_repo/1" do
      other = start_sqlite_repo(name: nil)
      SQLiteRepo.put_dynamic_repo(other)
      SQLiteRepo.query!("CREATE TABLE only_here (id INTEGER)")

      assert {:ok, %Exqlite.Result{rows: [[0]]}} =
               query(SQLiteRepo, ~q"SELECT count(*) FROM only_here")

      SQLiteRepo.put_dynamic_repo(SQLiteRepo)
      assert {:error, %Exqlite.Error{}} = query(SQLiteRepo, ~q"SELECT count(*) FROM only_here")
    end
  end

  describe "query/3 with a Postgres repo" do
    @describetag :live_postgres

    setup do
      start_postgres_repo()
      :ok
    end

    test "executes a Fragment with a Binding and a list/1 part" do
      assert {:ok, %Postgrex.Result{rows: [[2], [3]]}} =
               query(
                 PostgresRepo,
                 ~q"SELECT x FROM unnest(#{[1, 2, 3]}::int[]) AS x WHERE x IN #{list([2, 3])}"
               )
    end

    test "returns the error form untouched" do
      assert {:error, %Postgrex.Error{}} = query(PostgresRepo, ~q"SELECT * FROM missing")
    end
  end
end
