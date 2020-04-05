for adapter <- [Flippant.Adapter.Memory, Flippant.Adapter.Postgres, Flippant.Adapter.Redis] do
  defmodule Module.concat(adapter, Test) do
    use ExUnit.Case

    @adapter adapter
    @moduletag adapter: adapter

    defmodule TestRules do
      def enabled?("awesome", _enabled_for, %{awesome?: true}), do: true

      def enabled?("extreme", enabled_for, actor) do
        Enum.any?(enabled_for, &(actor.id == &1))
      end

      def enabled?("radical", _enabled_for, %{radical?: true}), do: true

      def enabled?("heinous", _enabled_for, %{awesome?: false}), do: true

      def enabled?(_group, _enabled_for, _actor), do: false
    end

    setup_all do
      Logger.configure(level: :warn)

      Application.stop(:flippant)
      Application.put_env(:flippant, :adapter, @adapter)
      Application.ensure_started(:flippant)

      Flippant.setup()

      :ok
    end

    setup do
      Flippant.clear()

      Application.put_env(:flippant, :rules, TestRules)

      on_exit(fn -> Application.put_env(:flippant, :rules, Default) end)
    end

    describe "add/1" do
      test "adds to the list of known features" do
        :ok = Flippant.add("search")
        :ok = Flippant.add("search")
        :ok = Flippant.add("delete")

        assert Flippant.features() == ["delete", "search"]
      end

      test "normalizes feature names" do
        Flippant.add("Search")
        Flippant.add(" search ")
        Flippant.add("\nSEARCH\t")

        assert Flippant.features() == ["search"]
      end
    end

    test "clear/0 removes all known features" do
      Flippant.add("search")

      assert Flippant.features() != []

      Flippant.clear()

      assert Flippant.features() == []
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

    describe "enable/3" do
      test "it adds a feature rule for a group" do
        Flippant.enable("search", "staff", [])
        Flippant.enable("search", "users", [])
        Flippant.enable("delete", "staff")

        assert Flippant.features() == ["delete", "search"]
        assert Flippant.features("staff") == ["delete", "search"]
        assert Flippant.features("users") == ["search"]
      end

      test "it merges additional values" do
        Flippant.enable("search", "members", [1])
        Flippant.enable("search", "members", [])
        Flippant.enable("search", "members", [2, 3])
        Flippant.enable("search", "members", [1])

        breakdown = Flippant.breakdown()

        assert breakdown["search"]
        assert breakdown["search"]["members"]
        assert Enum.sort(breakdown["search"]["members"]) == [1, 2, 3]
      end

      test "it operates atomically to avoid race conditions" do
        tasks =
          for value <- 1..6 do
            Task.async(fn -> Flippant.enable("search", "members", [value]) end)
          end

        Enum.each(tasks, &Task.await/1)

        breakdown = Flippant.breakdown()

        assert breakdown["search"]
        assert breakdown["search"]["members"]
        assert Enum.sort(breakdown["search"]["members"]) == [1, 2, 3, 4, 5, 6]
      end
    end

    describe "disable/2" do
      test "disables the feature for a group" do
        Flippant.enable("search", "staff", [])
        Flippant.enable("search", "users", [])

        Flippant.disable("search", "users")

        assert Flippant.features() == ["search"]
        assert Flippant.features("staff") == ["search"]
        assert Flippant.features("users") == []
      end

      test "retains the group and removes values" do
        Flippant.enable("search", "members", [1, 2])
        Flippant.disable("search", "members", [2])

        assert Flippant.breakdown() == %{
                 "search" => %{"members" => [1]}
               }
      end

      test "operates atomically to avoid race conditions" do
        Flippant.enable("search", "members", [1, 2, 3, 4, 5])

        tasks =
          for value <- [1, 3, 5] do
            Task.async(fn -> Flippant.disable("search", "members", [value]) end)
          end

        Enum.each(tasks, &Task.await/1)

        breakdown = Flippant.breakdown()

        assert breakdown["search"]
        assert breakdown["search"]["members"]
        assert Enum.sort(breakdown["search"]["members"]) == [2, 4]
      end
    end

    describe "rename/2" do
      test "rename an existing feature" do
        Flippant.enable("search", "members", [1])

        Flippant.rename("search", "super-search")

        assert Flippant.features() == ["super-search"]
      end

      test "normalize values while renaming" do
        Flippant.enable("search", "members")

        Flippant.rename(" SEARCH ", " SUPER-SEARCH ")

        assert Flippant.features() == ["super-search"]
      end

      test "clobber an existing feature with the same name" do
        Flippant.enable("search", "members", [1])
        Flippant.enable("super-search", "members", [2])

        Flippant.rename("search", "super-search")

        assert Flippant.breakdown() == %{
                 "super-search" => %{"members" => [1]}
               }
      end
    end

    test "enabled?/2 checks a feature for an actor" do
      actor_a = %{id: 1, awesome?: true}
      actor_b = %{id: 2, awesome?: false}

      refute Flippant.enabled?("search", actor_a)
      refute Flippant.enabled?("search", actor_b)

      Flippant.enable("search", "awesome")

      assert Flippant.enabled?("search", actor_a)
      refute Flippant.enabled?("search", actor_b)
    end

    test "enabled?/2 checks for a feature against multiple groups" do
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
      actor_a = %{id: 1}
      actor_b = %{id: 5}

      Flippant.enable("search", "extreme", [1, 2, 3])

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
        Flippant.enable("search", "awesome")
        Flippant.enable("search", "heinous", [%{awesome?: true, id: 1}, %{awesome?: true, id: 2}])
        Flippant.enable("delete", "radical")

        Flippant.enable("invite", "heinous", [
          %{awesome?: false, id: 5},
          %{awesome?: false, id: 6}
        ])

        %{"search" => search, "delete" => delete, "invite" => invite} = Flippant.breakdown()

        assert %{"awesome" => [], "heinous" => [_, _]} = search
        assert %{"radical" => []} = delete
        assert %{"heinous" => [_, _]} = invite
      end
    end

    describe "breakdown/1" do
      test "it is empty without any features" do
        assert Flippant.breakdown(%{id: 1}) == %{}
      end

      test "it lists all enabled features for an actor" do
        actor = %{id: 1, awesome?: true, radical?: true}

        Flippant.enable("search", "awesome")
        Flippant.enable("search", "heinous")
        Flippant.enable("delete", "radical")
        Flippant.enable("invite", "heinous")

        breakdown = Flippant.breakdown(actor)

        assert breakdown == %{
                 "delete" => true,
                 "invite" => false,
                 "search" => true
               }
      end
    end

    describe "dump/1 and load/1" do
      @dumpfile "flippant.dump"

      test "feature dumps may be restored using load" do
        Flippant.enable("search", "awesome")
        Flippant.enable("search", "heinous", [1, 2])
        Flippant.enable("delete", "radical")
        Flippant.enable("invite", "heinous", [5, 6])

        assert :ok = Flippant.dump(@dumpfile)
        assert :ok = Flippant.clear()
        assert %{} = Flippant.breakdown()
        assert :ok = Flippant.load(@dumpfile)

        %{"search" => search, "delete" => delete, "invite" => invite} = Flippant.breakdown()

        assert %{"awesome" => [], "heinous" => [_, _]} = search
        assert %{"radical" => []} = delete
        assert %{"heinous" => [5, 6]} = invite
      after
        File.rm(@dumpfile)
      end

      test "attempting to load from a missing dump fails gracefully" do
        assert {:error, :enoent} = Flippant.load(@dumpfile)
      end
    end
  end
end
