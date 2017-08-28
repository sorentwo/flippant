defmodule Flippant.Rules do
  @moduledoc """
  The Rules module glues rules, actors, and groups are together.
  """

  alias Flippant.Registry

  @doc """
  Check whether any rules are enabled for a particular actor. The function
  accepts a list of names/value pairs and an actor.

  # Example

      Flippant.Rules.enabled_for_actor?(rules, actor, groups)

  Without a third argument of the groups to be checked it falls back to
  collecting the globally registered groups.
  """
  @spec enabled_for_actor?(list, any, Map.t) :: boolean
  def enabled_for_actor?(rules, actor, groups \\ nil) do
    groups = groups || Registry.registered()

    Enum.any?(rules, fn {name, values} ->
      if fun = Map.get(groups, name) do
        apply(fun, [actor, values])
      end
    end)
  end
end
