defmodule PlainSQL.DialectTest do
  use ExUnit.Case, async: true

  alias PlainSQL.Dialect

  test "the behaviour defines placeholder/1 and identifier_delimiters/0 only" do
    assert Enum.sort(Dialect.behaviour_info(:callbacks)) ==
             [identifier_delimiters: 0, placeholder: 1]
  end

  for {module, placeholder_2, delimiters} <- [
        {Dialect.Postgres, "$2", {"\"", "\""}},
        {Dialect.SQLite, "?", {"\"", "\""}},
        {Dialect.MySQL, "?", {"`", "`"}},
        {Dialect.MSSQL, "@2", {"[", "]"}}
      ] do
    test "#{inspect(module)} implements the shipped table" do
      module = unquote(module)

      assert Dialect in Enum.flat_map(module.__info__(:attributes), fn
               {:behaviour, mods} -> mods
               _ -> []
             end)

      assert module.placeholder(2) == unquote(placeholder_2)
      assert module.identifier_delimiters() == unquote(Macro.escape(delimiters))
    end
  end
end
