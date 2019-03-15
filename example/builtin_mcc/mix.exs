defmodule BuiltinMcc.MixProject do
  use Mix.Project

  def project do
    [
      app: :builtin_mcc,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {BuiltinMcc.Application, []}
    ]
  end

  defp deps do
    [
      {:mcc, path: "../../../mcc"}
    ]
  end
end
