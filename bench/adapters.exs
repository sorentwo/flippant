defmodule Bench.Adapters do
  alias Flippant.Adapter.{Memory, Postgres, Redis}

  def run do
    Logger.configure(level: :warn)

    Benchee.run %{
      "breakdown" => fn(_adapter) -> Flippant.breakdown() end
    }, inputs: %{"memory" => Memory, "postgres" => Postgres, "redis" => Redis},
       before_scenario: &configure/1,
       formatter_options: %{console: %{extended_statistics: true}}
  end

  def configure(adapter) do
    Application.stop(:flippant)
    Application.put_env(:flippant, :adapter, adapter)
    Application.ensure_started(:flippant)

    Flippant.setup()
    Flippant.clear()

    Flippant.enable("search", "awesome")
    Flippant.enable("search", "heinous", [1, 2])
    Flippant.enable("delete", "radical")
    Flippant.enable("invite", "heinous", [5, 6])

    adapter
  end
end
