defmodule Flippant.Mixfile do
  use Mix.Project

  @version "3.0.0-dev"

  def project do
    [
      app: :flippant,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
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
      extra_applications: [:logger]
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
      {:jason, "~> 1.0"},
      {:postgrex, "~> 0.14", optional: true},
      {:ecto_sql, "~> 3.9", optional: true},
      {:redix, "~> 1.0", optional: true},
      {:benchee, "~> 1.0", only: [:dev], runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.19", only: [:dev, :test], runtime: false}
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
