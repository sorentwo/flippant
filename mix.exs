defmodule Flippant.Mixfile do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :flippant,
      version: @version,
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      description: description(),
      package: package(),
      name: "Flippant",
      deps: deps(),
      docs: docs(),
      dialyzer: [
        flags: [:error_handling, :race_conditions, :underspecs],
        plt_add_apps: [:db_connection, :decimal, :jason, :postgrex, :redix]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      env: [adapter: Flippant.Adapter.Memory, serializer: Flippant.Serializer.Term],
      mod: {Flippant.Application, []}
    ]
  end

  defp description do
    """
    Fast feature toggling for applications, with plugable backends.
    """
  end

  defp package do
    [
      maintainers: ["Parker Selbert"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/sorentwo/flippant"},
      files: ~w(lib mix.exs README.md CHANGELOG.md)
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.0", optional: true},
      {:postgrex, "~> 0.14", optional: true},
      {:redix, "~> 0.10", optional: true},
      {:benchee, "~> 1.0", only: [:dev], runtime: false},
      {:credo, "~> 1.0", only: [:dev], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.19", only: [:dev], runtime: false},
      {:inch_ex, "~> 0.5", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.11", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "Flippant",
      source_ref: @version,
      source_url: "https://github.com/sorentwo/flippant",
      extras: [
        "CHANGELOG.md"
      ]
    ]
  end
end
