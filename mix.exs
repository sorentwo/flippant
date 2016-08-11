defmodule Flippant.Mixfile do
  use Mix.Project

  @version "0.2.0"

  def project do
    [app: :flippant,
     version: @version,
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,

     description: description,
     package: package,

     deps: deps,

     name: "Flippant",
     source_url: "https://github.com/sorentwo/flippant",
     docs: [source_ref: "v#{@version}",
            extras: ["README.md"],
            main: "Flippant"]]
  end

  def application do
    [applications: [:logger],
     env: [adapter: Flippant.Adapter.Memory],
     mod: {Flippant, []}]
  end

  defp description do
    """
    Fast feature toggling for applications, backed by Redis.
    """
  end

  defp package do
    [maintainers: ["Parker Selbert"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/sorentwo/flippant"},
     files: ~w(lib mix.exs README.md CHANGELOG.md)]
  end

  defp deps do
    [{:redix, "~> 0.4", optional: true},
     {:ex_doc, ">= 0.0.0", only: :dev}]
  end
end
