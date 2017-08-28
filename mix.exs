defmodule Flippant.Mixfile do
  use Mix.Project

  @version "0.3.0"

  def project do
    [app: :flippant,
     version: @version,
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,

     test_coverage: [tool: ExCoveralls],

     description: description(),
     package: package(),

     name: "Flippant",

     deps: deps(),
     docs: docs()]
  end

  def application do
    [extra_applications: [:logger],
     env: [adapter: Flippant.Adapter.Memory],
     mod: {Flippant.Application, []}]
  end

  defp description do
    """
    Fast feature toggling for applications, with plugable backends.
    """
  end

  defp package do
    [maintainers: ["Parker Selbert"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/sorentwo/flippant"},
     files: ~w(lib mix.exs README.md CHANGELOG.md)]
  end

  defp deps do
    [{:postgrex, "~> 0.13", optional: true},
     {:redix, "~> 0.6", optional: true},
     {:poison, "~> 3.1", optional: true},

     {:ex_doc, ">= 0.0.0", only: :dev},
     {:inch_ex, ">= 0.0.0", only: :dev},
     {:excoveralls, "~> 0.7", only: [:dev, :test]}]
  end

  defp docs do
    [main: "flippant",
     source_ref: @version,
     source_url: "https://github.com/sorentwo/flippant"]
  end
end
