defmodule Flippant.Registry do
  @moduledoc """
  The registry stores group names with corresponding inclusion functions.

  Groups are used to identify and qualify `actors`. Typically an `actor` is a
  "user", but it could be a company, a device, or any other entity that needs
  to be classified.

  Using the example of a `User` some groups may be "nobody", "everbody",
  "admin", "staff", etc. Each named group is coupled with a function that
  accepts two arguments (the actor and optional values) and returns a boolean.
  When the return value is `true`, the actor belongs to that group. If the
  value is `false` then they aren't part of the group.

  ## Examples

      Flippant.register("nobody", fn(_, _) -> false end)
      #=> :ok

      Flippant.register("everybody", fn(_, _) -> true end)
      #=> :ok

  Group registry is stateful, and global to a Flippant instance. That means an actor
  can be evaulated against every group for every feature check. Be sure to add guards
  if you are mixing different types of actors.

      Flippant.register("enterprise", fn
        nil, _values -> false
        %User{}, _values -> false
        %Company{id: id}, values -> id in values
      end)
      #=> :ok
  """

  use GenServer

  @doc """
  Start the registry process.
  """
  @spec start_link() :: GenServer.on_start
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, [name: __MODULE__])
  end

  @doc false
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(__MODULE__)
    :ok
  end

  @doc false
  @spec register(binary, fun) :: :ok
  def register(group, fun) do
    :ets.insert(__MODULE__, {group, fun})
  end

  @doc false
  @spec registered() :: map
  def registered() do
    folder = fn({group, fun}), acc -> Map.put(acc, group, fun) end

    :ets.foldl(folder, %{}, __MODULE__)
  end

  # Callbacks

  def init(_opts) do
    {:ok, :ets.new(__MODULE__, [:named_table, :public, read_concurrency: true])}
  end
end
