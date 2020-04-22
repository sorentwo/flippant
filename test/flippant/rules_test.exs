defmodule Flippant.RulesTest do
  use ExUnit.Case

  alias Flippant.Rules
  alias Flippant.Rules.Default

  describe "enabled_for_actor?/2 with default rules" do
    test "nobody group is always disabled" do
      actor = %{id: 1, name: "Parker"}
      rule = %{"nobody" => []}

      refute Rules.enabled_for_actor?(rule, actor)
    end

    test "everybody group is always enabled for a feature" do
      actor = %{id: 1, name: "Parker"}
      rule = %{"everybody" => []}

      assert Rules.enabled_for_actor?(rule, actor)
    end

    test "unknown groups are always disabled for a feature" do
      actor = %{id: 1, name: "Parker"}
      rule = %{"users" => [1]}

      refute Rules.enabled_for_actor?(rule, actor)
    end
  end

  defmodule TestRules do
    def enabled?("staff", _enabled_for, %{staff?: true}), do: true

    def enabled?("users", enabled_for, actor) do
      Enum.any?(enabled_for, &(actor.id == &1))
    end

    def enabled?(_group, _enabled_for, _actor), do: false
  end

  describe "enabled_for_actor?/2 with custom rules" do
    setup do
      Flippant.update_config(:rules, TestRules)

      on_exit(fn -> Flippant.update_config(:rules, Default) end)
    end

    test "groups and membership are asserted through custom rules" do
      staff_actor = %{id: 1, name: "Parker", staff?: true}
      user_actor = %{id: 2, name: "Parker"}
      non_membered_actor = %{id: 3, name: "Parker"}

      rule = %{"staff" => [], "users" => [2]}

      assert Rules.enabled_for_actor?(rule, staff_actor)
      assert Rules.enabled_for_actor?(rule, user_actor)
      refute Rules.enabled_for_actor?(rule, non_membered_actor)
    end
  end
end
