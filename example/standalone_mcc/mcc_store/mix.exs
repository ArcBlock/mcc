defmodule MccStore.MixProject do
  use Mix.Project

  def project do
    [
      app: :mcc_store,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {MccStore.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mcc, github: "arcblock/mcc"}
    ]
  end
end
