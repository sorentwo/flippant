defmodule FlippantTest do
  use ExUnit.Case

  setup do
    Flippant.clear

    :ok
  end

  test "add/1 adds to the list of known features" do
    Flippant.add("search")
    Flippant.add("search")
    Flippant.add("delete")

    assert Flippant.features == ["delete", "search"]
  end

  test "clear/0 removes all known features" do
    Flippant.add("search")
    Flippant.add("delete")

    Flippant.clear

    assert Flippant.features == []
  end

  test "remove/1 removes a specific feature" do
    Flippant.add("search")
    Flippant.add("delete")
    Flippant.remove("search")

    assert Flippant.features == ["delete"]
  end

  test "enable/3 adds a feature rule for a group" do
    Flippant.enable("search", "staff", true)
    Flippant.enable("search", "users", false)
    Flippant.enable("delete", "staff")

    assert Flippant.features == ["delete", "search"]
    assert Flippant.features("staff") == ["delete", "search"]
    assert Flippant.features("users") == ["search"]
  end

  test "disable/2 disables a feature for a group" do
    Flippant.enable("search", "staff", true)
    Flippant.enable("search", "users", false)

    Flippant.disable("search", "users")

    assert Flippant.features == ["search"]
    assert Flippant.features("staff") == ["search"]
    assert Flippant.features("users") == []
  end

  # breakdown(actor)
  # enabled?(feature, actor)
end
