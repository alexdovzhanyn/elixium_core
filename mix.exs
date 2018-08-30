defmodule Elixium.Mixfile do
  use Mix.Project

  def project do
    [
      app: :elixium_core,
      version: "0.2.5",
      elixir: "~> 1.7",
      elixirc_paths: ["lib"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Elixium Core",
      description: description(),
      source_url: "https://github.com/elixium/elixium_core",
      homepage_url: "https://elixium.app",
      package: package()
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:exleveldb, "~> 0.12.2"},
      {:keccakf1600, "~> 2.0.0"},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: [:dev], runtime: false},
      {:decimal, "~> 1.0"},
      {:strap, "~> 0.1.1"},
      {:jason, "~> 1.0"}
    ]
  end

  defp description do
    "The core package for the Elixium blockchain, containing all the modules needed to run the chain"
  end

  defp package() do
    [
      name: "elixium_core",
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Alex Dovzhanyn", "Zac Garby", "Nijinsha Rahman"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/elixium/elixium_core"}
    ]
  end
end
