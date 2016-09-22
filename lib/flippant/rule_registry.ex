defmodule Flippant.RuleRegistry do
  @moduledoc """
  Rules represent individual features along with the group(s) the feature is
  enabled for. For example, "search", "analytics", "super-secret-feature" could
  all be rule names, and they could each be enabled for one or more groups.

  When `Flippant` is started the supervision tree automatically starts the
  `RuleRegistry`.

  ## Example

      iex> Flippant.RuleRegistry.enable("search", "awesome")
      :ok
      iex> Flippant.RuleRegistry.enabled?("search", awesome_actor)
      true
      iex> Flippant.RuleRegistry.disable("search", "awesome")
      :ok
      iex> Flippant.RuleRegistry.enabled?("search", awesome_actor)
      false
  """

  @doc """
  Start the registry with a particular adapter. The adapter will be linked to
  the registry.

  ## Example

      iex> Flippant.RuleRegistry.start_link(adapter: Flippant.Adapter.Memory)
      {:ok, pid}
  """
  @spec start_link([adapter: module]) :: Supervisor.on_start
  def start_link(options) do
    adapter = Keyword.fetch!(options, :adapter)

    adapter.start_link(options)
  end

  @doc """
  Add a new feature to the registry of known features. Note that adding a
  feature does not enable it for any groups, that can be done using `enable/2`
  or `enable/3`.

  ## Example

      iex> Flippant.RuleRegistry.add("search")
      :ok
  """
  @spec add(binary) :: :ok
  def add(feature) when is_binary(feature) do
    GenServer.cast(adapter, {:add, feature})
  end

  @doc """
  Breakdown without any arguments defaults to `:all`, and will list all
  registered features along with their group and value metadata. It is the only
  way to retrieve a snapshot of all the features in the system. The operation
  is optimized for round-trip efficiency.

  Alternatively, breakdown takes a single `actor` argument, typically a
  `%User{}` struct or some other entity. It generates a map outlining which
  features are enabled for the actor.

  ## Example

  Assuming the groups `awesome`, `heinous`, and `radical`, and the features
  `search`, `delete` and `invite` are enabled, the breakdown would look like:

      iex> Flippant.breakdown()
      %{"search" => %{"awesome" => [], "heinous" => []},
        "delete" => %{"radical" => []},
        "invite" => %{"heinous" => []}}

  Getting the breakdown for a particular actor:

      iex> actor = %User{ id: 1, awesome?: true, radical?: false}
      ...> Flippant.RuleRegistry.breakdown(actor)
      %{"delete" => true, "search" => false}
  """
  @spec breakdown(map | struct | :all) :: map
  def breakdown(actor \\ :all) do
    GenServer.call(adapter, {:breakdown, actor})
  end

  @doc """
  Clear all registered features and any of their associated rules.

  ## Example

      iex> Flippant.RuleRegistry.clear()
      :ok
  """
  @spec clear() :: :ok
  def clear do
    GenServer.cast(adapter, :clear)
  end

  @doc """
  Disable a feature for a particular group. The feature is kept in the
  registry, but any rules for that group are removed.

  ## Example

  Disable the `search` feature for the `adopters` group:

      iex> Flippant.RuleRegistry.disable("search", "adopters")
      :ok
  """
  @spec disable(binary, binary) :: :ok
  def disable(feature, group)
      when is_binary(feature)
      when is_binary(group) do

    GenServer.cast(adapter, {:remove, feature, group})
  end

  @doc """
  Fully remove a feature for all groups.

  ## Example

      iex> Flippant.RuleRegistry.remove("search")
      :ok
  """
  @spec remove(binary) :: :ok
  def remove(feature) when is_binary(feature) do
    GenServer.cast(adapter, {:remove, feature})
  end

  @doc """
  Features can be enabled for a group along with a set of values. The values
  will be passed along to the group's registered function when determining
  whether a feature is enabled for a particular actor.

  Values are useful when limiting a feature to a subset of actors by `id` or
  some other distinguishing factor.

  Value serialization can be customized by using an alternate module
  implementing the `Flippant.Serializer` behaviour.

  ## Example

  Enable the `search` feature for the `radical` group, without any specific
  values:

      iex> Flippant.RuleRegistry.enable("search", "radical")
      :ok

  Assuming the group `awesome` checks whether an actor's id is in the list of
  values, you would enable the `search` feature for actors 1, 2 and 3 like
  this:

      iex> Flippant.RuleRegistry.enable("search", "awesome", [1, 2, 3])
      :ok
  """
  @spec enable(binary, binary, any) :: :ok
  def enable(feature, group, values \\ true)
      when is_binary(feature)
      when is_binary(group) do

    GenServer.cast(adapter, {:add, feature, {group, values}})
  end

  @doc """
  Check if a particular feature is enabled for an actor. If the actor belongs
  to any groups that have access to the feature then it will be enabled.

  ## Example

      iex> Flippant.RuleRegistry.enabled?("search", actor)
      false
  """
  @spec enabled?(binary, map | struct) :: boolean
  def enabled?(feature, actor) when is_binary(feature) do
    GenServer.call(adapter, {:enabled?, feature, actor})
  end

  @doc """
  List all known features or only features enabled for a particular group.

  ## Example

  Given the features `search` and `delete`:

      iex> Flippant.RuleRegistry.features()
      ["search", "delete"]

      iex> Flippant.RuleRegistry.features(:all)
      ["search", "delete"]

  If the `search` feature were only enabled for the `awesome` group:

      iex> Flippant.RuleRegistry.features("awesome")
      ["search"]
  """
  @spec features(:all | binary) :: [binary]
  def features(group \\ :all) do
    GenServer.call(adapter, {:features, group})
  end

  @spec adapter() :: pid
  defp adapter(), do: Flippant.Adapter.adapter()
end
