defmodule PlainSQL.FragmentTest do
  use ExUnit.Case, async: true

  import PlainSQL

  describe "inspect/2" do
    test "shows a Binding as ? and the values in text order" do
      fragment = ~q"SELECT * FROM orders WHERE status = #{"open"} AND total > #{10}"

      assert inspect(fragment) ==
               ~s|#PlainSQL.Fragment<"SELECT * FROM orders WHERE status = ? AND total > ?", ["open", 10]>|
    end

    test "shows a list part as one ? per element inside parentheses" do
      assert inspect(~q"id IN #{list([1, 2])}") == ~s|#PlainSQL.Fragment<"id IN (?, ?)", [1, 2]>|
    end

    test "shows an Identifier inside double quotes" do
      assert inspect(identifier("orders")) == ~s|#PlainSQL.Fragment<"\\"orders\\"", []>|
    end

    test "shows an Identifier that contains a double quote" do
      assert inspect(identifier(~s|a"b|)) == ~s|#PlainSQL.Fragment<"\\"a\\"b\\"", []>|
    end

    test "shows the Empty Fragment" do
      assert inspect(~q"") == ~s|#PlainSQL.Fragment<"", []>|
    end

    test "applies the inspect options to the values" do
      fragment = ~q"name = #{"abcdef"} AND id IN #{list([1, 2, 3])}"

      assert inspect(fragment, limit: 2, printable_limit: 3) ==
               ~s|#PlainSQL.Fragment<"name = ? AND id IN (?, ?, ?)", ["abc" <> ..., 1, ...]>|
    end
  end
end
