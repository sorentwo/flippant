defmodule Flippant.Rules do
  alias Flippant.GroupRegistry

  def enabled_for_actor?(rules, actor) do
    registered = GroupRegistry.registered

    Enum.any?(rules, fn {group, values} ->
      if fun = Map.get(registered, group) do
        apply(fun, [actor, values])
      end
    end)
  end
end
