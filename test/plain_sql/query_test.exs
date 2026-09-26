defmodule PlainSQL.QueryTest do
  use ExUnit.Case, async: true

  import PlainSQL

  alias PlainSQL.Dialect.MSSQL
  alias PlainSQL.Dialect.MySQL
  alias PlainSQL.Dialect.Postgres
  alias PlainSQL.Dialect.SQLite
  alias PlainSQL.TestSupport.LiveDB
  alias PlainSQL.TestSupport.UnknownConnection

  describe "dialect/1 with a connection" do
    @tag :live_postgres
    test "returns Postgres for a Postgrex pool" do
      {:ok, conn} = LiveDB.start_postgrex()
      assert dialect(conn) == Postgres
    end

    test "returns SQLite for an Exqlite pool" do
      {:ok, conn} = LiveDB.start_exqlite()
      assert dialect(conn) == SQLite
    end

    test "accepts a registered name" do
      {:ok, _} = LiveDB.start_exqlite(name: :plain_sql_named_sqlite)
      assert dialect(:plain_sql_named_sqlite) == SQLite
    end

    test "accepts a via tuple" do
      {:ok, _} = Registry.start_link(keys: :unique, name: PlainSQL.TestRegistry)
      via = {:via, Registry, {PlainSQL.TestRegistry, :sqlite}}
      {:ok, _} = LiveDB.start_exqlite(name: via)

      assert dialect(via) == SQLite
    end

    test "accepts the handle inside run/3 and transaction/3" do
      {:ok, conn} = LiveDB.start_exqlite()

      assert DBConnection.run(conn, &dialect/1) == SQLite
      assert DBConnection.transaction(conn, &dialect/1) == {:ok, SQLite}
    end

    test "raises ArgumentError naming the value for a process that is not a pool" do
      error = assert_raise ArgumentError, fn -> dialect(self()) end
      assert error.message =~ inspect(self())
    end

    test "raises ArgumentError naming the module for a connection module with no table row" do
      {:ok, conn} = DBConnection.start_link(UnknownConnection, pool_size: 1)

      error = assert_raise ArgumentError, fn -> dialect(conn) end
      assert error.message =~ inspect(UnknownConnection)
    end
  end

  describe "query/3 with an Exqlite connection" do
    setup do
      {:ok, conn} = LiveDB.start_exqlite()
      Exqlite.query!(conn, "CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT)", [])
      Exqlite.query!(conn, "INSERT INTO t (id, name) VALUES (1, 'a'), (2, 'b'), (3, 'c')", [])
      %{conn: conn}
    end

    test "returns the Driver result untouched", %{conn: conn} do
      assert {:ok, %Exqlite.Result{rows: [[2, "b"], [3, "c"]]}} =
               query(conn, ~q"SELECT id, name FROM t WHERE id IN #{list([2, 3])} ORDER BY id")

      assert {:error, %Exqlite.Error{}} = query(conn, ~q"SELECT * FROM missing WHERE id = #{1}")
    end

    test "executes the UPDATE and the clause idioms", %{conn: conn} do
      assignments = set([~q"name = #{"z"}", nil])
      assert {:ok, _} = query(conn, ~q"UPDATE t #{assignments} WHERE id = #{1}")

      select =
        ~q"SELECT name, count(*) FROM t #{where(nil)} #{group_by([~q"name"])} #{having(~q"count(*) > #{0}")} #{order_by([~q"name DESC", false])}"

      assert {:ok, %Exqlite.Result{rows: [["z", 1], ["c", 1], ["b", 1]]}} = query(conn, select)
    end

    test "raises on inference failure before Rendering" do
      fragment = ~q"SELECT #{identifier(~s|a"b|)}"

      error = assert_raise ArgumentError, fn -> query(self(), fragment) end
      assert error.message =~ inspect(self())
    end

    test "opts reach the Driver unchanged", %{conn: conn} do
      # `run/3` holds the only connection of the pool.
      result =
        DBConnection.run(conn, fn _ ->
          query(conn, ~q"SELECT 1", queue: false)
        end)

      assert {:error, %DBConnection.ConnectionError{}} = result
    end

    test "sends the Empty Fragment to the Driver as an empty statement" do
      # Exqlite 0.41 raises on an empty statement. The raise kills the connection, so each
      # call gets its own pool.
      {:ok, driver_conn} = LiveDB.start_exqlite()
      {:ok, conn} = LiveDB.start_exqlite()

      assert catch_error(query(conn, ~q"")) == catch_error(Exqlite.query(driver_conn, "", []))
    end
  end

  describe "query/3 with a Postgrex connection" do
    @describetag :live_postgres

    setup do
      {:ok, conn} = LiveDB.start_postgrex()
      %{conn: conn}
    end

    test "returns the Driver result untouched", %{conn: conn} do
      assert {:ok, %Postgrex.Result{rows: [[2], [3]]}} =
               query(
                 conn,
                 ~q"SELECT x FROM unnest(#{[1, 2, 3]}::int[]) AS x WHERE x IN #{list([2, 3])}"
               )

      assert {:error, %Postgrex.Error{}} = query(conn, ~q"SELECT * FROM missing WHERE id = #{1}")
    end

    test "opts reach the Driver unchanged", %{conn: conn} do
      assert {:ok, %Postgrex.Result{rows: [{1}]}} =
               query(conn, ~q"SELECT #{1}::int", decode_mapper: &List.to_tuple/1)
    end

    test "a bare list binds as one array; = ANY([]) matches no row, <> ALL([]) every row",
         %{conn: conn} do
      rows = fn ids, op ->
        {:ok, %Postgrex.Result{rows: rows}} =
          query(
            conn,
            ~q"SELECT x FROM unnest(#{[1, 2, 3]}::int[]) AS x WHERE x #{op}(#{ids}) ORDER BY x"
          )

        rows
      end

      assert rows.([1, 2], ~q"= ANY") == [[1], [2]]
      assert rows.([], ~q"= ANY") == []
      assert rows.([], ~q"<> ALL") == [[1], [2], [3]]
    end

    test "sends the Empty Fragment to the Driver as an empty statement", %{conn: conn} do
      assert query(conn, ~q"") == Postgrex.query(conn, "", [])
    end
  end

  describe "MyXQL and Tds dispatch" do
    # The pools use the test doubles of test/support/fake_drivers.ex.
    setup do
      {:ok, mysql} = DBConnection.start_link(MyXQL.Connection, pool_size: 1)
      {:ok, mssql} = DBConnection.start_link(Tds.Protocol, pool_size: 1)
      %{mysql: mysql, mssql: mssql}
    end

    test "dialect/1 maps MyXQL.Connection to MySQL and Tds.Protocol to MSSQL", ctx do
      assert dialect(ctx.mysql) == MySQL
      assert dialect(ctx.mssql) == MSSQL
    end

    test "the MyXQL path calls MyXQL.query/4 with the rendered params unchanged", ctx do
      assert query(ctx.mysql, ~q"a = #{1} AND b IN #{list([2, 3])}", timeout: 5) ==
               {:fake_query, MyXQL, ctx.mysql, "a = ? AND b IN (?, ?)", [1, 2, 3], timeout: 5}
    end

    test "the Tds path wraps each param in a Tds.Parameter named after its placeholder", ctx do
      assert query(ctx.mssql, ~q"a = #{1} AND b IN #{list([2, 3])}", timeout: 5) ==
               {:fake_query, Tds, ctx.mssql, "a = @1 AND b IN (@2, @3)",
                [
                  %Tds.Parameter{name: "@1", value: 1},
                  %Tds.Parameter{name: "@2", value: 2},
                  %Tds.Parameter{name: "@3", value: 3}
                ], timeout: 5}
    end
  end
end
