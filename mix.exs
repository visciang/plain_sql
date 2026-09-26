defmodule PlainSQL.MixProject do
  use Mix.Project

  def project do
    [
      app: :plain_sql,
      version: "0.1.0",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
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
      {:decimal, "~> 3.1", only: :test},
      {:postgrex, "~> 0.22", only: :test},
      {:exqlite, "~> 0.41", only: :test}
    ]
  end
end
