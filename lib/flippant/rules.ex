defmodule Flippant.Rules do
  @moduledoc """
  The Rules module is where rules, actors, and groups are glued together.
  """

  alias Flippant.GroupRegistry

  @doc """
  Check whether any rules are enabled for a particular actor.
  """
  @spec enabled_for_actor?(list, any) :: boolean
  def enabled_for_actor?(rules, actor) do
    registered = GroupRegistry.registered

    Enum.any?(rules, fn {group, values} ->
      if fun = Map.get(registered, group) do
        apply(fun, [actor, values])
      end
    end)
  end
end
