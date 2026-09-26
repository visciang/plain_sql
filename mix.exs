defmodule PlainSQL.MixProject do
  use Mix.Project

  def project do
    [
      app: :plain_sql,
      version: "0.1.0",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  defp aliases do
    [
      all: ["compile --warnings-as-errors", "format --check-formatted", "dialyzer", "coveralls"]
    ]
  end

  def cli do
    [preferred_envs: [all: :test, coveralls: :test, "coveralls.html": :test]]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:db_connection, "~> 2.10", optional: true},
      {:ecto_sql, "~> 3.14", optional: true},
      {:postgrex, "~> 0.22", only: :test},
      {:exqlite, "~> 0.41", only: :test},
      {:ecto_sqlite3, "~> 0.25", only: :test},
      {:excoveralls, "~> 0.18", only: :test},
      {:dialyxir, "~> 1.4", only: :test, runtime: false}
    ]
  end
end
