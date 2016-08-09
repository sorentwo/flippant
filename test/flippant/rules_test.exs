defmodule Flippant.RulesTest do
  use ExUnit.Case, async: true

  alias Flippant.Rules

  describe "enabled_for_actor?/3" do
    actor = %{id: 1, name: "Parker"}
    group = %{"chosen" => fn(%{id: id}, value) -> id == value end}

    refute Rules.enabled_for_actor?([], actor)
    refute Rules.enabled_for_actor?([], actor, %{})
    refute Rules.enabled_for_actor?([{"chosen", 1}], actor, %{})

    assert Rules.enabled_for_actor?([{"chosen", 1}], actor, group)
  end
end
