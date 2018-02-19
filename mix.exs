defmodule UltraDark.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ultradark_core,
      version: "0.1.0",
      elixir: "~> 1.5",
      elixirc_paths: ["lib"],
      start_permanent: Mix.env == :prod,
      deps: deps(),
      name: "UltraDark Core",
      description: description(),
      source_url: "https://github.com/ultradark/ultradark_core"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:exleveldb, "~> 0.12.2"},
      {:keccakf1600, "~> 2.0.0"}
    ]
  end

  defp description do
    "A description"
  end

  defp package() do
    [
      name: "ultradark_core",
      files: ["lib", "mix.exs", "README*", "readme*", "LICENSE*", "license*"],
      maintainers: ["Alex Dovzhanyn", "Zac Garby", "Nijinsha Rahman"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/ultradark/ultradark_core"}
    ]
  end
end
