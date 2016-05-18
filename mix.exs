defmodule Flippant.Mixfile do
  use Mix.Project

  def project do
    [app: :flippant,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger],
     env: [adapter: Flippant.Adapter.Memory],
     mod: {Flippant, []}]
  end

  defp deps do
    [{:redix, "~> 0.3", optional: true}]
  end
end
