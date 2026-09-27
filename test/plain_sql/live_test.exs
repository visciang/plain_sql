defmodule PlainSQL.LiveTest do
  use ExUnit.Case, async: true

  import PlainSQL

  alias PlainSQL.Dialect.Postgres
  alias PlainSQL.Dialect.SQLite
  alias PlainSQL.TestSupport.LiveDB

  describe "rendered SQL executes on SQLite" do
    setup do
      {:ok, conn} = LiveDB.start_exqlite()
      Exqlite.query!(conn, "CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT)", [])
      Exqlite.query!(conn, "INSERT INTO t (id, name) VALUES (1, 'a'), (2, 'b'), (3, 'c')", [])
      %{conn: conn}
    end

    test "list/1 binds one param per element", %{conn: conn} do
      {sql, params} =
        render(~q"SELECT id, name FROM t WHERE id IN #{list([2, 3])} ORDER BY id", SQLite)

      assert {:ok, %Exqlite.Result{rows: [[2, "b"], [3, "c"]]}} = Exqlite.query(conn, sql, params)
    end

    test "the UPDATE and the clause idioms", %{conn: conn} do
      assignments = set([~q"name = #{"z"}", nil])
      {sql, params} = render(~q"UPDATE t #{assignments} WHERE id = #{1}", SQLite)
      assert {:ok, _} = Exqlite.query(conn, sql, params)

      select =
        ~q"SELECT name, count(*) FROM t #{where(nil)} #{group_by([~q"name"])} #{having(~q"count(*) > #{0}")} #{order_by([~q"name DESC", false])}"

      {sql, params} = render(select, SQLite)

      assert {:ok, %Exqlite.Result{rows: [["z", 1], ["c", 1], ["b", 1]]}} =
               Exqlite.query(conn, sql, params)
    end
  end

  describe "rendered SQL executes on Postgres" do
    @describetag :live_postgres

    setup do
      {:ok, conn} = LiveDB.start_postgrex()
      %{conn: conn}
    end

    test "list/1 binds one param per element", %{conn: conn} do
      {sql, params} =
        render(
          ~q"SELECT x FROM unnest(#{[1, 2, 3]}::int[]) AS x WHERE x IN #{list([2, 3])}",
          Postgres
        )

      assert {:ok, %Postgrex.Result{rows: [[2], [3]]}} = Postgrex.query(conn, sql, params)
    end

    test "a bare list binds as one array; = ANY([]) matches no row, <> ALL([]) every row",
         %{conn: conn} do
      rows = fn ids, op ->
        {sql, params} =
          render(
            ~q"SELECT x FROM unnest(#{[1, 2, 3]}::int[]) AS x WHERE x #{op}(#{ids}) ORDER BY x",
            Postgres
          )

        {:ok, %Postgrex.Result{rows: rows}} = Postgrex.query(conn, sql, params)
        rows
      end

      assert rows.([1, 2], ~q"= ANY") == [[1], [2]]
      assert rows.([], ~q"= ANY") == []
      assert rows.([], ~q"<> ALL") == [[1], [2], [3]]
    end
  end
end
