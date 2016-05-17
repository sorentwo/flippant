defmodule Flippant do
  use Application

  require Flippant.Adapter

  alias Flippant.{Adapter, Registry}

  def start(_, _) do
    import Supervisor.Spec

    children = [
      worker(Adapter.adapter, []),
      worker(Registry, [])
    ]

    options = [strategy: :one_for_one, name: Flippant.Supervisor]

    Supervisor.start_link(children, options)
  end

  defdelegate [register(group, fun), registered], to: Registry

  Adapter.defdelegate [
    add(feature),
    breakdown(actor),
    enable(feature, group),
    enable(feature, group, values),
    enabled?(feature, actor),
    disable(feature, group),
    features,
    features(group),
    remove(feature)
  ]

  def reset! do
    Adapter.adapter.clear && Registry.clear
  end
end
