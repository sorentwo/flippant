defmodule Flippant do
  use Application

  alias Flippant.Adapters.Memory

  def start(_, _) do
    import Supervisor.Spec

    children = [
      worker(Memory, [])
    ]

    options = [strategy: :one_for_one, name: Flippant.Supervisor]

    Supervisor.start_link(children, options)
  end

  defdelegate add(feature), to: Memory
  defdelegate clear, to: Memory
  defdelegate enable(feature, group), to: Memory
  defdelegate enable(feature, group, values), to: Memory
  defdelegate disable(feature, group), to: Memory
  defdelegate features, to: Memory
  defdelegate features(group), to: Memory
  defdelegate remove(feature), to: Memory
end
