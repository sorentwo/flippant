defmodule Flippant do
  use Application

  alias Flippant.Adapters.Memory
  alias Flippant.Registry

  def start(_, _) do
    import Supervisor.Spec

    children = [
      worker(Memory, []),
      worker(Registry, [])
    ]

    options = [strategy: :one_for_one, name: Flippant.Supervisor]

    Supervisor.start_link(children, options)
  end

  defdelegate [add(feature),
               enable(feature, group),
               enable(feature, group, values),
               enabled?(feature, actor),
               disable(feature, group),
               features,
               features(group),
               remove(feature)], to: Memory

  defdelegate [register(group, fun)], to: Registry

  def reset! do
    Memory.clear && Registry.clear
  end
end
