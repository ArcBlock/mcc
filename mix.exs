defmodule Mcc.MixProject do
  use Mix.Project

  def project do
    [
      app: :mcc,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Mcc.Application, []}
    ]
  end

  defp deps do
    [
      {:excoveralls, "~> 0.10", only: [:test]}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # __end_of_module__
end
