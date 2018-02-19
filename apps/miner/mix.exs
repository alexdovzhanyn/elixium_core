defmodule Miner.Mixfile do
  use Mix.Project

  def project do
    [
      app: :miner,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.5",
      elixirc_paths: ["lib", "../../core"],
      start_permanent: Mix.env == :prod,
      deps: deps(),
      test_paths: ["../../test"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    []
  end
end
