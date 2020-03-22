defmodule Flippant.Rules do
  @moduledoc """
  The Rules module glues rules, actors, and groups are together.
  """

  @type rules :: Enumerable.t()
  @type actor :: term()

  @doc """
  Validate that an actor is both a member of `group` and in the `enabled_for` list. For example,
  if we had a `staff` group, and a rule containing `%{"staff" => ids}`, we could have a function
  like this:

  ```
    def enabled?("staff", enabled_for, %{staff: true} = actor) do
      Enum.any?(enabled_for, &actor.id == &1.id)
    end
  ```

  This both validates the actor is staff, and that the actor is in the enabled list. Allowing
  rules definition in this way makes the logic for rule checking very visible in application
  code.
  """
  @callback enabled?(group :: binary(), enabled_for :: list(), actor :: Rules.actor()) ::
              boolean()

  @doc """
  Check whether any rules are enabled for a particular actor. The function
  accepts a list of names/value pairs and an actor.
  """
  @spec enabled_for_actor?(rules(), actor()) :: boolean()
  def enabled_for_actor?(rules, actor) do
    ruleset = Application.fetch_env!(:flippant, :rules)

    Enum.any?(rules, fn {group, enabled_for} ->
      ruleset.enabled?(group, enabled_for, actor)
    end)
  end
end
