defmodule Flippant do
  use Application

  alias Flippant.{GroupRegistry, RuleRegistry}

  def start(_, _) do
    import Supervisor.Spec

    adapter = Application.get_env(:flippant, :adapter)

    children = [
      worker(GroupRegistry, []),
      worker(RuleRegistry, [[adapter: adapter]])
    ]

    options = [strategy: :one_for_one, name: Flippant.Supervisor]

    Supervisor.start_link(children, options)
  end

  defdelegate [add(feature),
               breakdown(actor),
               enable(feature, group),
               enable(feature, group, values),
               enabled?(feature, actor),
               disable(feature, group),
               features,
               features(group),
               remove(feature)], to: RuleRegistry

  defdelegate [register(group, fun),
               registered], to: GroupRegistry

  def reset do
    GroupRegistry.clear && RuleRegistry.clear
  end
end
