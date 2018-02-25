defmodule UltraDark.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ultradark_core,
      version: "0.1.0",
      elixir: "~> 1.5",
      elixirc_paths: ["lib"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "UltraDark Core",
      description: description(),
      source_url: "https://github.com/ultradark/ultradark_core",
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
      {:jsonrpc2, "~> 1.0"},
      {:poison, "~> 3.1"},
      {:shackle, "~> 0.5"},
      {:ranch, "~> 1.3"}
    ]
  end

  defp description do
    "The core package for the UltraDark blockchain, containing all the modules needed to run the chain"
  end

  defp package() do
    [
      name: "ultradark_core",
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Alex Dovzhanyn", "Zac Garby", "Nijinsha Rahman"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/ultradark/ultradark_core"}
    ]
  end
end
