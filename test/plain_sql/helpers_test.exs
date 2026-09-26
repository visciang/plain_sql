defmodule PlainSQL.HelpersTest do
  use ExUnit.Case, async: true

  import PlainSQL

  alias PlainSQL.Dialect.MSSQL
  alias PlainSQL.Dialect.MySQL
  alias PlainSQL.Dialect.Postgres
  alias PlainSQL.Dialect.SQLite

  @empty %PlainSQL.Fragment{parts: []}

  describe "identifier/1" do
    test "renders the name inside the delimiter pair of each Dialect" do
      fragment = ~q"SELECT * FROM #{identifier("users")}"

      assert render(fragment, Postgres) == {~s|SELECT * FROM "users"|, []}
      assert render(fragment, SQLite) == {~s|SELECT * FROM "users"|, []}
      assert render(fragment, MySQL) == {"SELECT * FROM `users`", []}
      assert render(fragment, MSSQL) == {"SELECT * FROM [users]", []}
    end

    test "raises ArgumentError for a non-binary and for an empty name" do
      assert_raise ArgumentError, fn -> identifier(:users) end
      assert_raise ArgumentError, fn -> identifier("") end
    end

    test "has no composite form" do
      assert render(~q"#{identifier("public.users")}", Postgres) == {~s|"public.users"|, []}

      assert render(~q"#{identifier("public")}.#{identifier("users")}", Postgres) ==
               {~s|"public"."users"|, []}
    end

    test "render/2 raises ArgumentError for a name that contains a delimiter of the Dialect" do
      quote_name = identifier(~s|a"b|)
      bracket_name = identifier("a]b")

      assert_raise ArgumentError, fn -> render(quote_name, Postgres) end
      assert_raise ArgumentError, fn -> render(bracket_name, MSSQL) end
      assert render(quote_name, MSSQL) == {~s|[a"b]|, []}
      assert render(bracket_name, Postgres) == {~s|"a]b"|, []}
    end
  end

  describe "raw/1" do
    test "produces one text part" do
      assert raw("SELECT 1").parts == [{:text, "SELECT 1"}]
    end

    test "raw(\"\") is the Empty Fragment" do
      assert raw("") == @empty
    end

    test "raises ArgumentError for a non-binary" do
      assert_raise ArgumentError, fn -> raw(:select) end
    end

    test "splices verbatim" do
      assert render(~q"SELECT #{raw("count(*)")} FROM t", Postgres) ==
               {"SELECT count(*) FROM t", []}
    end
  end

  describe "join/2" do
    test "renders the members in order with the separator between them" do
      fragment = join([~q"a", ~q"b", ~q"c"], ~q", ")

      assert render(fragment, Postgres) == {"a, b, c", []}
    end

    test "repeats a Binding inside the separator once per gap in text order" do
      fragment = join([~q"a = #{1}", ~q"b = #{2}", ~q"c = #{3}"], ~q" #{"AND"} ")

      assert render(fragment, Postgres) == {"a = $1 $2 b = $3 $4 c = $5", [1, "AND", 2, "AND", 3]}
    end

    test "skips nil, false, and the Empty Fragment" do
      fragment = join([nil, ~q"a", false, ~q"", ~q"b"], ~q", ")

      assert render(fragment, Postgres) == {"a, b", []}
    end

    test "renders the Empty Fragment when no member remains" do
      assert join([], ~q", ") == @empty
      assert join([nil, false, ~q""], ~q", ") == @empty
    end

    test "raises ArgumentError for a member that is not a Fragment, nil, or false" do
      assert_raise ArgumentError, fn -> join([~q"a", "b"], ~q", ") end
      assert_raise ArgumentError, fn -> join([true], ~q", ") end
    end

    test "raises ArgumentError for a separator that is not a Fragment" do
      assert_raise ArgumentError, fn -> apply(PlainSQL, :join, [[~q"a"], ", "]) end
    end
  end

  describe "list/1" do
    test "renders one placeholder per element inside parentheses on every Dialect" do
      fragment = ~q"id IN #{list([1, 2, 3])}"

      assert render(fragment, Postgres) == {"id IN ($1, $2, $3)", [1, 2, 3]}
      assert render(fragment, SQLite) == {"id IN (?, ?, ?)", [1, 2, 3]}
      assert render(fragment, MySQL) == {"id IN (?, ?, ?)", [1, 2, 3]}
      assert render(fragment, MSSQL) == {"id IN (@1, @2, @3)", [1, 2, 3]}
    end

    test "raises ArgumentError for an empty list" do
      assert_raise ArgumentError, fn -> list([]) end
    end

    test "produces one list part with the values unchanged" do
      values = [1, "a", nil, %{b: 2}]
      assert list(values).parts == [{:list, values}]
    end

    test "takes placeholders n..n+k-1 and the following Binding takes n+k" do
      assert render(~q"a = #{0} AND id IN #{list([1, 2])} AND b = #{3}", Postgres) ==
               {"a = $1 AND id IN ($2, $3) AND b = $4", [0, 1, 2, 3]}
    end

    test "a bare list in \#{} binds as one value" do
      ids = [1, 2]
      assert render(~q"id = ANY(#{ids})", Postgres) == {"id = ANY($1)", [[1, 2]]}
    end

    test "renders a VALUES row with parentheses included" do
      assert render(~q"VALUES #{list(["a", "b"])}", Postgres) == {"VALUES ($1, $2)", ["a", "b"]}
    end

    test "the multi-row VALUES idiom is join/2 over one list/1 per row" do
      rows = [[1, "open"], [2, "closed"]]
      fragment = ~q"VALUES #{join(Enum.map(rows, &list/1), ~q", ")}"

      assert render(fragment, Postgres) == {"VALUES ($1, $2), ($3, $4)", [1, "open", 2, "closed"]}
    end
  end

  describe "all/1" do
    test "joins the members with AND and wraps each in parentheses" do
      assert render(all([~q"a = #{1}", ~q"b = #{2}"]), Postgres) ==
               {"(a = $1) AND (b = $2)", [1, 2]}
    end

    test "wraps a single remaining member in parentheses" do
      assert render(all([nil, ~q"a = #{1}"]), Postgres) == {"(a = $1)", [1]}
    end

    test "skips nil, false, and the Empty Fragment" do
      assert render(all([nil, ~q"a", false, ~q"", ~q"b"]), Postgres) == {"(a) AND (b)", []}
    end

    test "renders the Empty Fragment when no member remains" do
      assert all([]) == @empty
      assert all([nil, false, ~q""]) == @empty
    end

    test "raises ArgumentError for a member that is not a Fragment, nil, or false" do
      assert_raise ArgumentError, fn -> all([~q"a", "b"]) end
    end
  end

  describe "any/1" do
    test "joins the members with OR and wraps each in parentheses" do
      assert render(any([~q"a = #{1}", ~q"b = #{2}"]), Postgres) ==
               {"(a = $1) OR (b = $2)", [1, 2]}
    end

    test "wraps a single remaining member in parentheses" do
      assert render(any([false, ~q"a = #{1}"]), Postgres) == {"(a = $1)", [1]}
    end

    test "skips nil, false, and the Empty Fragment" do
      assert render(any([nil, ~q"a", false, ~q"", ~q"b"]), Postgres) == {"(a) OR (b)", []}
    end

    test "raises ArgumentError when no member remains" do
      assert_raise ArgumentError, fn -> any([]) end
      assert_raise ArgumentError, fn -> any([nil, false, ~q""]) end
    end

    test "raises ArgumentError for a member that is not a Fragment, nil, or false" do
      assert_raise ArgumentError, fn -> any([~q"a", "b"]) end
    end

    test "nested all/any numbers Bindings in text order" do
      fragment = all([any([~q"a = #{1}", ~q"b = #{2}"]), ~q"c = #{3}"])

      assert render(fragment, Postgres) == {"((a = $1) OR (b = $2)) AND (c = $3)", [1, 2, 3]}
    end
  end

  describe "where/1" do
    test "renders WHERE followed by the Fragment" do
      assert render(where(~q"a = #{1}"), Postgres) == {"WHERE a = $1", [1]}
    end

    test "renders the Empty Fragment for the Empty Fragment" do
      assert where(~q"") == @empty
    end

    test "renders the Empty Fragment for nil and false" do
      assert where(nil) == @empty
      assert where(false) == @empty
    end

    test "raises ArgumentError for an argument that is not a Fragment, nil, or false" do
      # apply/3 hides the argument from the compile-time type check.
      assert_raise ArgumentError, fn -> apply(PlainSQL, :where, [1]) end
      assert_raise ArgumentError, fn -> apply(PlainSQL, :where, ["a = 1"]) end
    end

    test "the conds idiom renders with and without the WHERE clause" do
      query = fn status, ids ->
        conds = all([~q"status = #{status}", ids != [] && ~q"id IN #{list(ids)}"])
        render(~q"SELECT * FROM orders #{where(conds)}", Postgres)
      end

      assert query.("open", [1, 2]) ==
               {"SELECT * FROM orders WHERE (status = $1) AND (id IN ($2, $3))", ["open", 1, 2]}

      assert query.("open", []) == {"SELECT * FROM orders WHERE (status = $1)", ["open"]}

      conds = all([nil, false])

      assert render(~q"SELECT * FROM orders #{where(conds)}", Postgres) ==
               {"SELECT * FROM orders ", []}
    end

    test "no limit, offset, returning, or negation helper exists" do
      for name <- [:limit, :offset, :returning, :negate, :prefix, :optional] do
        refute function_exported?(PlainSQL, name, 1)
        refute function_exported?(PlainSQL, name, 2)
      end
    end
  end

  describe "having/1" do
    test "renders HAVING followed by the Fragment" do
      assert render(having(~q"count(*) > #{1}"), Postgres) == {"HAVING count(*) > $1", [1]}
    end

    test "renders the Empty Fragment for the Empty Fragment, nil, and false" do
      assert having(~q"") == @empty
      assert having(nil) == @empty
      assert having(false) == @empty
    end

    test "raises ArgumentError for an argument that is not a Fragment, nil, or false" do
      assert_raise ArgumentError, fn -> apply(PlainSQL, :having, [1]) end
    end
  end

  describe "group_by/1" do
    test "renders GROUP BY followed by the members joined with a comma" do
      assert render(group_by([~q"a", ~q"b"]), Postgres) == {"GROUP BY a, b", []}
    end

    test "skips nil, false, and the Empty Fragment" do
      assert render(group_by([nil, ~q"a", false, ~q"", ~q"b"]), Postgres) == {"GROUP BY a, b", []}
    end

    test "renders the Empty Fragment when no member remains" do
      assert group_by([]) == @empty
      assert group_by([nil, false, ~q""]) == @empty
    end

    test "raises ArgumentError for a member that is not a Fragment, nil, or false" do
      assert_raise ArgumentError, fn -> group_by([~q"a", "b"]) end
    end
  end

  describe "order_by/1" do
    test "renders ORDER BY followed by the members joined with a comma" do
      assert render(order_by([~q"a DESC", false, ~q"b"]), Postgres) == {"ORDER BY a DESC, b", []}
    end

    test "renders the Empty Fragment when no member remains" do
      assert order_by([nil]) == @empty
    end

    test "raises ArgumentError for a member that is not a Fragment, nil, or false" do
      assert_raise ArgumentError, fn -> order_by([true]) end
    end
  end

  describe "set/1" do
    test "renders SET followed by the members joined with a comma, Bindings in text order" do
      assert render(set([~q"a = #{1}", nil, ~q"b = #{2}"]), Postgres) ==
               {"SET a = $1, b = $2", [1, 2]}
    end

    test "raises ArgumentError when no member remains" do
      assert_raise ArgumentError, fn -> set([]) end
      assert_raise ArgumentError, fn -> set([nil, false, ~q""]) end
    end

    test "raises ArgumentError for a member that is not a Fragment, nil, or false" do
      assert_raise ArgumentError, fn -> set([~q"a = 1", "b = 2"]) end
    end

    test "the UPDATE idiom renders on Postgres" do
      update = fn status, note, id ->
        fragment =
          ~q"UPDATE orders #{set([~q"status = #{status}", note && ~q"note = #{note}"])} WHERE id = #{id}"

        render(fragment, Postgres)
      end

      assert update.("open", "rush", 7) ==
               {"UPDATE orders SET status = $1, note = $2 WHERE id = $3", ["open", "rush", 7]}

      assert update.("open", nil, 7) ==
               {"UPDATE orders SET status = $1 WHERE id = $2", ["open", 7]}
    end
  end

  describe "SELECT clause idiom" do
    test "renders with and without the optional clauses" do
      query = fn ids, by_name ->
        fragment =
          ~q"SELECT status, count(*) FROM orders #{where(ids != [] && ~q"id IN #{list(ids)}")} #{group_by([~q"status"])} #{having(by_name && ~q"count(*) > #{1}")} #{order_by([~q"status", by_name && ~q"count(*) DESC"])}"

        render(fragment, Postgres)
      end

      assert query.([1, 2], true) ==
               {"SELECT status, count(*) FROM orders WHERE id IN ($1, $2) GROUP BY status HAVING count(*) > $3 ORDER BY status, count(*) DESC",
                [1, 2, 1]}

      assert query.([], false) ==
               {"SELECT status, count(*) FROM orders  GROUP BY status  ORDER BY status", []}
    end
  end

  describe "empty?/1" do
    test "is true for the Empty Fragment, nil, and false" do
      assert empty?(~q"")
      assert empty?(raw(""))
      assert empty?(all([]))
      assert empty?(nil)
      assert empty?(false)
    end

    test "is false for a Fragment with a part" do
      refute empty?(~q"a")
      refute empty?(~q"#{1}")
    end

    test "raises ArgumentError for an argument that is not a Fragment, nil, or false" do
      assert_raise ArgumentError, fn -> apply(PlainSQL, :empty?, [1]) end
      assert_raise ArgumentError, fn -> apply(PlainSQL, :empty?, [""]) end
    end
  end

  describe "INSERT idiom" do
    test "renders on all four Dialects" do
      table = "orders"
      names = ["id", "status"]
      values = [1, "open"]

      cols = join(Enum.map(names, &identifier/1), ~q", ")
      fragment = ~q"INSERT INTO #{identifier(table)} (#{cols}) VALUES #{list(values)}"

      assert render(fragment, Postgres) ==
               {~s|INSERT INTO "orders" ("id", "status") VALUES ($1, $2)|, [1, "open"]}

      assert render(fragment, SQLite) ==
               {~s|INSERT INTO "orders" ("id", "status") VALUES (?, ?)|, [1, "open"]}

      assert render(fragment, MySQL) ==
               {"INSERT INTO `orders` (`id`, `status`) VALUES (?, ?)", [1, "open"]}

      assert render(fragment, MSSQL) ==
               {"INSERT INTO [orders] ([id], [status]) VALUES (@1, @2)", [1, "open"]}
    end
  end
end
