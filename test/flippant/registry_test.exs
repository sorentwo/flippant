defmodule Flippant.RegistryTest do
  use ExUnit.Case

  setup do
    on_exit(fn -> Flippant.clear(:registered) end)

    :ok
  end

  describe "register/2" do
    test "adding a new group" do
      assert :ok = Flippant.register("a", fn _, _ -> false end)
    end

    test "unable to create group with wrong arity" do
      assert_raise FunctionClauseError, fn ->
        Flippant.register("a", fn -> false end)
      end
    end
  end

  describe "registered/0" do
    test "retrieving all registered groups" do
      fun = fn _, _ -> true end

      :ok = Flippant.register("a", fun)
      :ok = Flippant.register("b", fun)
      :ok = Flippant.register("c", fun)

      assert Flippant.registered() == %{"a" => fun, "b" => fun, "c" => fun}
    end
  end
end
