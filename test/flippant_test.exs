for adapter <- [Flippant.Adapter.Memory, Flippant.Adapter.Redis] do
  defmodule Module.concat(adapter, Test) do
    use ExUnit.Case

    @adapter adapter
    @moduletag adapter: adapter

    setup_all do
      Logger.configure(level: :warn)

      Application.stop(:flippant)
      Application.put_env(:flippant, :adapter, @adapter)
      Application.ensure_started(:flippant)

      :ok
    end

    setup do
      Flippant.clear()

      :ok
    end

    test "add/1 adds to the list of known features" do
      :ok = Flippant.add("search")
      :ok = Flippant.add("search")
      :ok = Flippant.add("delete")

      assert Flippant.features() == ["delete", "search"]
    end

    test "clear/0 removes all known groups and features" do
      Flippant.add("search")
      Flippant.register("awesome", fn(_, _) -> true end)

      assert Flippant.features() != []
      assert Flippant.registered() != %{}

      Flippant.clear()

      assert Flippant.features() == []
      assert Flippant.registered() == %{}
    end

    test "clear/1 removes either groups or features" do
      Flippant.add("search")
      Flippant.register("awesome", fn(_, _) -> true end)

      Flippant.clear(:features)

      assert Flippant.features() == []
      refute Flippant.registered() == %{}

      Flippant.clear(:groups)

      assert Flippant.registered() == %{}
    end

    test "remove/1 removes a specific feature" do
      Flippant.add("search")
      Flippant.add("delete")

      Flippant.remove("search")
      assert Flippant.features() == ["delete"]

      Flippant.remove("delete")
      assert Flippant.features() == []
      assert Flippant.features("users") == []
    end

    test "enable/3 adds a feature rule for a group" do
      Flippant.enable("search", "staff", true)
      Flippant.enable("search", "users", false)
      Flippant.enable("delete", "staff")

      assert Flippant.features() == ["delete", "search"]
      assert Flippant.features("staff") == ["delete", "search"]
      assert Flippant.features("users") == ["search"]
    end

    test "disable/2 disables a feature for a group" do
      Flippant.enable("search", "staff", true)
      Flippant.enable("search", "users", false)

      Flippant.disable("search", "users")

      assert Flippant.features() == ["search"]
      assert Flippant.features("staff") == ["search"]
      assert Flippant.features("users") == []
    end

    test "enabled?/2 checks a feature for an actor" do
      Flippant.register("staff", fn(actor, _values) -> actor.staff? end)

      actor_a = %{id: 1, staff?: true}
      actor_b = %{id: 2, staff?: false}

      refute Flippant.enabled?("search", actor_a)
      refute Flippant.enabled?("search", actor_b)

      Flippant.enable("search", "staff")

      assert Flippant.enabled?("search", actor_a)
      refute Flippant.enabled?("search", actor_b)
    end

    test "enabled?/2 checks for a feature against multiple groups" do
      Flippant.register("awesome", fn(actor, _) -> actor.awesome? end)
      Flippant.register("radical", fn(actor, _) -> actor.radical? end)

      actor_a = %{id: 1, awesome?: true, radical?: false}
      actor_b = %{id: 2, awesome?: false, radical?: true}
      actor_c = %{id: 3, awesome?: false, radical?: false}

      Flippant.enable("search", "awesome")
      Flippant.enable("search", "radical")

      assert Flippant.enabled?("search", actor_a)
      assert Flippant.enabled?("search", actor_b)
      refute Flippant.enabled?("search", actor_c)
    end

    test "enabled?/2 uses rule values when checking" do
      Flippant.register("awesome", fn(actor, ids) -> actor.id in ids end)

      actor_a = %{id: 1}
      actor_b = %{id: 5}

      Flippant.enable("search", "awesome", [1, 2, 3])

      assert Flippant.enabled?("search", actor_a)
      refute Flippant.enabled?("search", actor_b)
    end

    describe "exists?/1" do
      test "it checks whether a feature exists" do
        Flippant.add("search")

        assert Flippant.exists?("search")
        refute Flippant.exists?("breach")
      end
    end

    describe "exists?/2" do
      test "it checks whether a feature and a group exist" do
        Flippant.enable("search", "nobody")

        assert Flippant.exists?("search", "nobody")
        refute Flippant.exists?("search", "everybody")
      end
    end

    describe "breakdown/0" do
      test "it expands all groups and values" do
        assert Flippant.breakdown() == %{}
      end

      test "it lists all features with their metadata" do
        Flippant.register("awesome", fn(_, _) -> true end)
        Flippant.register("radical", fn(_, _) -> false end)
        Flippant.register("heinous", fn(_, _) -> false end)

        Flippant.enable("search", "awesome")
        Flippant.enable("search", "heinous", [1, 2])
        Flippant.enable("delete", "radical")
        Flippant.enable("invite", "heinous", [5, 6])

        assert Flippant.breakdown() == %{
          "search" => %{"awesome" => true, "heinous" => [1, 2]},
          "delete" => %{"radical" => true},
          "invite" => %{"heinous" => [5, 6]}
        }
      end
    end

    describe "breakdown/1" do
      test "it works without any features" do
        assert Flippant.breakdown(%{id: 1}) == %{}
      end

      test "it lists all enabled features for an actor" do
        Flippant.register("awesome", fn(actor, _) -> actor.awesome? end)
        Flippant.register("radical", fn(actor, _) -> actor.radical? end)
        Flippant.register("heinous", fn(actor, _) -> !actor.awesome? end)

        actor = %{id: 1, awesome?: true, radical?: true}

        Flippant.enable("search", "awesome")
        Flippant.enable("search", "heinous")
        Flippant.enable("delete", "radical")
        Flippant.enable("invite", "heinous")

        breakdown = Flippant.breakdown(actor)

        assert Map.keys(breakdown) == ~w(delete invite search)

        assert breakdown == %{
          "delete" => true,
          "invite" => false,
          "search" => true
        }
      end
    end
  end
end
