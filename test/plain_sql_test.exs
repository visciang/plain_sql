defmodule PlainSQLTest do
  use ExUnit.Case, async: true

  import PlainSQL

  alias PlainSQL.Dialect.MSSQL
  alias PlainSQL.Dialect.MySQL
  alias PlainSQL.Dialect.Postgres
  alias PlainSQL.Dialect.SQLite

  describe "render/2" do
    test "renders plain text with no params" do
      assert render(~q"SELECT 1", Postgres) == {"SELECT 1", []}
    end

    test "renders a Binding as a numbered placeholder on Postgres" do
      assert render(~q"SELECT * FROM t WHERE id = #{1}", Postgres) ==
               {"SELECT * FROM t WHERE id = $1", [1]}
    end

    test "renders a Binding as ? on SQLite" do
      assert render(~q"SELECT * FROM t WHERE id = #{1}", SQLite) ==
               {"SELECT * FROM t WHERE id = ?", [1]}
    end

    test "numbers Bindings in text order across a Splice" do
      cond_ = ~q"status = #{"open"}"

      assert render(~q"SELECT * FROM t WHERE #{cond_} AND total > #{10}", Postgres) ==
               {"SELECT * FROM t WHERE status = $1 AND total > $2", ["open", 10]}
    end

    test "a Fragment spliced twice contributes its Bindings twice" do
      cond_ = ~q"status = #{"open"}"

      assert render(~q"SELECT #{cond_} OR #{cond_}", Postgres) ==
               {"SELECT status = $1 OR status = $2", ["open", "open"]}
    end

    test "binds every non-Fragment value unchanged" do
      values = ["text", [1, 2], %{a: 1}, nil, ~D[2026-09-26], Decimal.new("1.50")]

      for value <- values do
        assert render(~q"SELECT #{value}", Postgres) == {"SELECT $1", [value]}
      end
    end

    test "the same Fragment renders on every Dialect with only the placeholders changed" do
      fragment = ~q"SELECT * FROM t WHERE a = #{1} AND b = #{2}"

      assert render(fragment, Postgres) == {"SELECT * FROM t WHERE a = $1 AND b = $2", [1, 2]}
      assert render(fragment, SQLite) == {"SELECT * FROM t WHERE a = ? AND b = ?", [1, 2]}
      assert render(fragment, MySQL) == {"SELECT * FROM t WHERE a = ? AND b = ?", [1, 2]}
      assert render(fragment, MSSQL) == {"SELECT * FROM t WHERE a = @1 AND b = @2", [1, 2]}
    end

    test "renders an Identifier inside the delimiter pair of the Dialect" do
      fragment = %PlainSQL.Fragment{parts: [{:text, "SELECT "}, {:identifier, "Users"}]}

      assert render(fragment, Postgres) == {~s|SELECT "Users"|, []}
      assert render(fragment, MySQL) == {"SELECT `Users`", []}
      assert render(fragment, MSSQL) == {"SELECT [Users]", []}
    end

    test "raises ArgumentError for an Identifier that contains a delimiter" do
      open = %PlainSQL.Fragment{parts: [{:identifier, "a[b"}]}
      close = %PlainSQL.Fragment{parts: [{:identifier, "a]b"}]}

      assert_raise ArgumentError, fn -> render(open, MSSQL) end
      assert_raise ArgumentError, fn -> render(close, MSSQL) end
      assert render(open, Postgres) == {~s|"a[b"|, []}
    end

    test "renders a list part as parenthesised placeholders in Binding order" do
      fragment = %PlainSQL.Fragment{
        parts: [{:text, "WHERE a = "}, {:binding, 0}, {:text, " AND id IN "}, {:list, [1, 2, 3]}]
      }

      assert render(fragment, Postgres) == {"WHERE a = $1 AND id IN ($2, $3, $4)", [0, 1, 2, 3]}
      assert render(fragment, SQLite) == {"WHERE a = ? AND id IN (?, ?, ?)", [0, 1, 2, 3]}
    end
  end

  describe "~q Splicing" do
    test "a Fragment in a variable and a Fragment written inline produce identical parts" do
      status = "open"
      cond_ = ~q"status = #{status}"

      from_variable = ~q"SELECT * FROM t WHERE #{cond_}"
      inline = ~q"SELECT * FROM t WHERE #{~q"status = #{status}"}"

      assert from_variable.parts == inline.parts

      assert from_variable.parts == [
               {:text, "SELECT * FROM t WHERE "},
               {:text, "status = "},
               {:binding, "open"}
             ]
    end

    test "~q\"\" is the Empty Fragment" do
      assert ~q"" == %PlainSQL.Fragment{parts: []}
      assert render(~q"", Postgres) == {"", []}
    end

    test "splicing the Empty Fragment adds no text and no Bindings" do
      empty = ~q""
      assert ~q"SELECT 1#{empty}".parts == [{:text, "SELECT 1"}]
    end

    test "drops empty text parts" do
      assert ~q"#{1}#{2}".parts == [{:binding, 1}, {:binding, 2}]
    end
  end

  describe "~q text" do
    test "keeps a backslash escape as two characters" do
      assert render(~q"SELECT '\n'", Postgres) == {"SELECT '\\n'", []}
    end

    test "turns an escaped delimiter into the delimiter" do
      assert render(~q"SELECT \"a\"", Postgres) == {"SELECT \"a\"", []}
    end

    test "accepts alternate delimiters" do
      assert render(~q|SELECT "a"|, Postgres) == {"SELECT \"a\"", []}
    end

    test "heredoc form strips indentation" do
      fragment = ~q"""
      SELECT *
      FROM t
      """

      assert render(fragment, Postgres) == {"SELECT *\nFROM t\n", []}
    end
  end

  describe "~q compile-time checks" do
    test "a modifier raises ArgumentError" do
      assert_raise ArgumentError, fn ->
        compile(~S|~q"SELECT 1"pg|)
      end
    end

    test "an empty \#{} raises ArgumentError" do
      assert_raise ArgumentError, fn ->
        compile(~S|~q"SELECT #{}"|)
      end
    end

    defp compile(source) do
      Code.compile_string("import PlainSQL\n" <> source)
    end
  end
end
