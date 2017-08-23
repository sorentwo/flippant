defmodule Flippant do
  alias Flippant.Registry

  @doc """
  Add a new feature to the registry of known features. Note that adding a
  feature does not enable it for any groups, that can be done using `enable/2`
  or `enable/3`.

  # Example

      iex> Flippant.add("search")
  """
  @spec add(binary) :: :ok
  def add(feature) when is_binary(feature) do
    GenServer.cast(adapter(), {:add, normalize(feature)})
  end

  @doc """
  Breakdown without any arguments defaults to `:all`, and will list all
  registered features along with their group and value metadata. It is the only
  way to retrieve a snapshot of all the features in the system. The operation
  is optimized for round-trip efficiency.

  Alternatively, breakdown takes a single `actor` argument, typically a
  `%User{}` struct or some other entity. It generates a map outlining which
  features are enabled for the actor.

  # Example

  Assuming the groups `awesome`, `heinous`, and `radical`, and the features
  `search`, `delete` and `invite` are enabled, the breakdown would look like:

      iex> Flippant.breakdown()
      %{"search" => %{"awesome" => [], "heinous" => []},
        "delete" => %{"radical" => []},
        "invite" => %{"heinous" => []}}

  Getting the breakdown for a particular actor:

      iex> actor = %User{ id: 1, awesome?: true, radical?: false}
      ...> Flippant.breakdown(actor)
      %{"delete" => true, "search" => false}
  """
  @spec breakdown(map | struct | :all) :: map
  def breakdown(actor \\ :all) do
    GenServer.call(adapter(), {:breakdown, actor})
  end

  @doc """
  Purge all of the registered groups and features. This is particularly useful
  in testing when you want to reset to a clean slate after a test.

  # Example

  Clear only features:

      iex> Flippant.clear(:features)
      :ok

  Clear only groups:

      iex> Flippant.clear(:groups)
      :ok
  """
  @spec clear(:features | :groups) :: :ok
  def clear do
    :ok = clear(:groups)
    :ok = clear(:features)

    :ok
  end
  def clear(:features) do
    GenServer.cast(adapter(), :clear)
  end
  def clear(:groups) do
    Registry.clear()
  end

  @doc """
  Disable a feature for a particular group. The feature is kept in the
  registry, but any rules for that group are removed.

  # Example

  Disable the `search` feature for the `adopters` group:

      iex> Flippant.disable("search", "adopters")

  Alternatively, individual values may be disabled for a group. This is useful
  when a group should stay enabled and only a single value (i.e. user id) needs
  to be removed.

  # Example

  Disable `search` feature for a user in the `adopters` group:

      iex> Flippant.disable("search", "adopters", [123])
      :ok
  """
  @spec disable(binary, binary) :: :ok
  def disable(feature, group, values \\ [])
      when is_binary(feature)
      and is_binary(group)
      and is_list(values) do

    GenServer.cast(adapter(), {:remove, normalize(feature), group, values})
  end

  @doc """
  Features can be enabled for a group along with a set of values. The values
  will be passed along to the group's registered function when determining
  whether a feature is enabled for a particular actor.

  Values are useful when limiting a feature to a subset of actors by `id` or
  some other distinguishing factor.

  Value serialization can be customized by using an alternate module
  implementing the `Flippant.Serializer` behaviour.

  # Example

  Enable the `search` feature for the `radical` group, without any specific
  values:

      iex> Flippant.enable("search", "radical")
      :ok

  Assuming the group `awesome` checks whether an actor's id is in the list of
  values, you would enable the `search` feature for actors 1, 2 and 3 like
  this:

      iex> Flippant.enable("search", "awesome", [1, 2, 3])
      :ok
  """
  @spec enable(binary, binary, list(any)) :: :ok
  def enable(feature, group, values \\ [])
      when is_binary(feature)
      and is_binary(group) do

    GenServer.cast(adapter(), {:add, normalize(feature), {group, values}})
  end

  @doc """
  Check if a particular feature is enabled for an actor. If the actor belongs
  to any groups that have access to the feature then it will be enabled.

  # Example

      iex> Flippant.enabled?("search", actor)
      false
  """
  @spec enabled?(binary, map | struct) :: boolean
  def enabled?(feature, actor) when is_binary(feature) do
    GenServer.call(adapter(), {:enabled?, normalize(feature), actor})
  end

  @doc """
  Check whether a given feature has been registered in the system. If a `group`
  is also sent it will check whether the feature has any rules for that group.

  # Example

      iex> Flippant.exists?("search")
      false

      iex> Flippant.add("search")
      ...> Flippant.exists?("search")
      true
  """
  @spec exists?(binary, binary | :any) :: boolean
  def exists?(feature, group \\ :any) do
    GenServer.call(adapter(), {:exists?, normalize(feature), group})
  end

  @doc """
  List all known features or only features enabled for a particular group.

  # Example

  Given the features `search` and `delete`:

      iex> Flippant.features()
      ["search", "delete"]

      iex> Flippant.features(:all)
      ["search", "delete"]

  If the `search` feature were only enabled for the `awesome` group:

      iex> Flippant.features("awesome")
      ["search"]
  """
  @spec features(:all | binary) :: list(binary)
  def features(group \\ :all) do
    GenServer.call(adapter(), {:features, group})
  end

  @doc """
  Rename an existing feature.

  If the new feature name already exists it will overwritten and all of the
  rules will be replaced.

  # Example

      iex> Flippant.rename("search", "super-search")
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

  # Example

      iex> Flippant.remove("search")
      :ok
  """
  @spec remove(binary) :: :ok
  def remove(feature) when is_binary(feature) do
    GenServer.cast(adapter(), {:remove, normalize(feature)})
  end

  defdelegate register(group, fun), to: Registry
  defdelegate registered(), to: Registry

  @doc """
  Retrieve the `pid` of the configured adapter process. It is expected that the
  adapter has been started.
  """
  @spec adapter() :: pid
  def adapter do
    :flippant
    |> Application.get_env(:adapter)
    |> Process.whereis()
  end

  defp normalize(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.trim()
  end
end
