defmodule Flippant do
  use Application

  alias Flippant.{GroupRegistry, RuleRegistry}

  def start(_, _) do
    import Supervisor.Spec

    flippant_opts = Application.get_all_env(:flippant)

    children = [
      worker(GroupRegistry, []),
      worker(RuleRegistry, [flippant_opts])
    ]

    opts = [strategy: :one_for_one, name: Flippant.Supervisor]

    Supervisor.start_link(children, opts)
  end

  defdelegate add(feature), to: RuleRegistry
  defdelegate breakdown(), to: RuleRegistry
  defdelegate breakdown(actor), to: RuleRegistry
  defdelegate enable(feature, group), to: RuleRegistry
  defdelegate enable(feature, group, values), to: RuleRegistry
  defdelegate enabled?(feature, actor), to: RuleRegistry
  defdelegate disable(feature, group), to: RuleRegistry
  defdelegate features(), to: RuleRegistry
  defdelegate features(group), to: RuleRegistry
  defdelegate remove(feature), to: RuleRegistry

  defdelegate register(group, fun), to: GroupRegistry
  defdelegate registered, to: GroupRegistry

  def reset do
    GroupRegistry.clear && RuleRegistry.clear
  end
end
