defmodule Flippant do
  alias Flippant.Registry

  # Adapter

  @doc """
  Retrieve the `pid` of the configured adapter process.

  This will return `nil` if the adapter hasn't been started.
  """
  @spec adapter() :: pid | nil
  def adapter do
    :flippant
    |> Application.get_env(:adapter)
    |> Process.whereis()
  end

  @doc """
  Add a new feature without any rules.

  Adding a feature does not enable it for any groups, that can be done using
  `enable/2` or `enable/3`.

  ## Examples

      Flippant.add("search")
      #=> :ok
  """
  @spec add(binary) :: :ok
  def add(feature) when is_binary(feature) do
    GenServer.cast(adapter(), {:add, normalize(feature)})
  end

  @doc """
  Generate a mapping of all features and associated rules.

  Breakdown without any arguments defaults to `:all`, and will list all
  registered features along with their group and value metadata. It is the only
  way to retrieve a snapshot of all the features in the system. The operation
  is optimized for round-trip efficiency.

  Alternatively, breakdown takes a single `actor` argument, typically a
  `%User{}` struct or some other entity. It generates a map outlining which
  features are enabled for the actor.

  ## Examples

  Assuming the groups `awesome`, `heinous`, and `radical`, and the features
  `search`, `delete` and `invite` are enabled, the breakdown would look like:

      Flippant.breakdown()
      #=> %{"search" => %{"awesome" => [], "heinous" => []},
            "delete" => %{"radical" => []},
            "invite" => %{"heinous" => []}}

  Getting the breakdown for a particular actor:

      actor = %User{ id: 1, awesome?: true, radical?: false}
      Flippant.breakdown(actor)
      #=> %{"delete" => true, "search" => false}
  """
  @spec breakdown(map | struct | :all) :: map
  def breakdown(actor \\ :all) do
    GenServer.call(adapter(), {:breakdown, actor})
  end

  @doc """
  Purge registered groups, features, or both.

  This is particularly useful in testing when you want to reset to a clean
  slate after a test.

  ## Examples

  Clear everything:

      Flippant.clear()
      #=> :ok

  Clear only features:

      Flippant.clear(:features)
      #=> :ok

  Clear only groups:

      Flippant.clear(:groups)
      #=> :ok
  """
  @spec clear(:features | :groups) :: :ok
  def clear(selection \\ nil)
  def clear(:features) do
    GenServer.cast(adapter(), :clear)
  end
  def clear(:groups) do
    Registry.clear()
  end
  def clear(_) do
    :ok = clear(:groups)
    :ok = clear(:features)

    :ok
  end

  @doc """
  Disable a feature for a particular group.

  The feature is kept in the registry, but any rules for that group are
  removed.

  ## Examples

  Disable the `search` feature for the `adopters` group:

      Flippant.disable("search", "adopters")
      #=> :ok

  Alternatively, individual values may be disabled for a group. This is useful
  when a group should stay enabled and only a single value (i.e. user id) needs
  to be removed.

  Disable `search` feature for a user in the `adopters` group:

      Flippant.disable("search", "adopters", [123])
      #=> :ok
  """
  @spec disable(binary, binary) :: :ok
  def disable(feature, group, values \\ [])
      when is_binary(feature)
      and is_binary(group)
      and is_list(values) do

    GenServer.cast(adapter(), {:remove, normalize(feature), group, values})
  end

  @doc """
  Enable a feature for a particular group.

  Features can be enabled for a group along with a set of values. The values
  will be passed along to the group's registered function when determining
  whether a feature is enabled for a particular actor.

  Values are useful when limiting a feature to a subset of actors by `id` or
  some other distinguishing factor. Value serialization can be customized by
  using an alternate module implementing the `Flippant.Serializer` behaviour.

  ## Examples

  Enable the `search` feature for the `radical` group, without any specific
  values:

      Flippant.enable("search", "radical")
      #=> :ok

  Assuming the group `awesome` checks whether an actor's id is in the list of
  values, you would enable the `search` feature for actors 1, 2 and 3 like
  this:

      Flippant.enable("search", "awesome", [1, 2, 3])
      #=> :ok
  """
  @spec enable(binary, binary, list(any)) :: :ok
  def enable(feature, group, values \\ [])
      when is_binary(feature)
      and is_binary(group) do

    GenServer.cast(adapter(), {:add, normalize(feature), {group, values}})
  end

  @doc """
  Check if a particular feature is enabled for an actor.

  If the actor belongs to any groups that have access to the feature then it
  will be enabled.

  ## Examples

      Flippant.enabled?("search", actor)
      #=> false
  """
  @spec enabled?(binary, map | struct) :: boolean
  def enabled?(feature, actor) when is_binary(feature) do
    GenServer.call(adapter(), {:enabled?, normalize(feature), actor})
  end

  @doc """
  Check whether a given feature has been registered.

  If a `group` is provided it will check whether the feature has any rules for
  that group.

  ## Examples

      Flippant.exists?("search")
      #=> false

      Flippant.add("search")
      Flippant.exists?("search")
      #=> true
  """
  @spec exists?(binary, binary | :any) :: boolean
  def exists?(feature, group \\ :any) do
    GenServer.call(adapter(), {:exists?, normalize(feature), group})
  end

  @doc """
  List all known features or only features enabled for a particular group.

  ## Examples

  Given the features `search` and `delete`:

      Flippant.features()
      #=> ["search", "delete"]

      Flippant.features(:all)
      #=> ["search", "delete"]

  If the `search` feature were only enabled for the `awesome` group:

      Flippant.features("awesome")
      #=> ["search"]
  """
  @spec features(:all | binary) :: list(binary)
  def features(group \\ :all) do
    GenServer.call(adapter(), {:features, group})
  end

  @doc """
  Rename an existing feature.

  If the new feature name already exists it will overwritten and all of the
  rules will be replaced.

  ## Examples

      Flippant.rename("search", "super-search")
      :ok
  """
  @spec rename(binary, binary) :: :ok
  def rename(old_name, new_name)
      when is_binary(old_name)
      and is_binary(new_name) do

    GenServer.cast(adapter(), {:rename, normalize(old_name), normalize(new_name)})
  end

  @doc """
  Fully remove a feature for all groups.

  ## Examples

      Flippant.remove("search")
      :ok
  """
  @spec remove(binary) :: :ok
  def remove(feature) when is_binary(feature) do
    GenServer.cast(adapter(), {:remove, normalize(feature)})
  end

  @doc """
  Prepare the adapter for usage.

  For adapters that don't require any setup this is a no-op. For other adapters,
  such as Postgres, which require a schema/table to operate this will create the
  necessary table.

  ## Examples

      Flippant.setup()
      :ok
  """
  @spec setup() :: :ok
  def setup do
    GenServer.cast(adapter(), :setup)
  end

  defp normalize(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.trim()
  end

  # Registry

  @doc """
  Register a new group name and function.

  The function *must* have an arity of 2 or it won't be accepted. Registering
  a group with the same name will overwrite the previous group.

  ## Examples

      Flippant.register("evens", & rem(&1.id, 2) == 0)
      #=> :ok
  """
  @spec register(binary, (any, list -> boolean)) :: :ok
  def register(group, fun) when is_binary(group) and is_function(fun, 2) do
    Registry.register(group, fun)
  end

  @doc """
  List all of the registered groups as a map where the keys are the names and
  values are the functions.

  ## Examples

      Flippant.registered()
      #=> %{"staff" => #Function<20.50752066/0}
  """
  @spec registered() :: map
  def registered do
    Registry.registered()
  end
end
