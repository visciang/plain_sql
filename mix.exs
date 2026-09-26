defmodule PlainSQL.MixProject do
  use Mix.Project

  def project do
    [
      app: :plain_sql,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp deps do
    [
      {:decimal, "~> 3.1", only: :test}
    ]
  end
end
