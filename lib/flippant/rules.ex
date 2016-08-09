defmodule Flippant.Rules do
  @moduledoc """
  The Rules module glues rules, actors, and groups are together.
  """

  alias Flippant.GroupRegistry

  @doc """
  Check whether any rules are enabled for a particular actor. The function
  accepts a list of names/value pairs and an actor.

  ## Example

      rules = [%{"staff", [1, 2]}, %{"people", []}]
      actor = %User{id: 1, name: "Parker"}
      group = %{"staff" => fn(_, _) -> true end}

      Flippant.Rules.enabled_for_actor?(rules, actor) #=> false

  Without a third argument of the groups to be checked it falls back to
  collecting the globally registered groups.

      Flippant.Rules.enabled_for_actor?(rules, actor, group) #=> true
  """
  @spec enabled_for_actor?(list, any, Map.t) :: boolean
  def enabled_for_actor?(rules, actor, groups \\ nil) do
    groups = groups || GroupRegistry.registered()

    Enum.any?(rules, fn {name, values} ->
      if fun = Map.get(groups, name) do
        apply(fun, [actor, values])
      end
    end)
  end
end
