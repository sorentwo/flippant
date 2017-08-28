defmodule Flippant.Application do
  @moduledoc false

  use Application

  import Supervisor.Spec

  @doc false
  def start(_, _) do
    children = [
      worker(Flippant.Registry, []),
      worker(adapter(), [flippant_opts()])
    ]

    opts = [strategy: :one_for_one, name: Flippant.Supervisor]

    Supervisor.start_link(children, opts)
  end

  defp adapter do
    Application.get_env(:flippant, :adapter)
  end

  defp flippant_opts do
    Application.get_all_env(:flippant)
  end
end
