defmodule Flippant.GroupRegistry do
  @moduledoc """
  Named groups are stored within a GroupRegistry process. Groups are used to
  identify and qualify actors within a system. Typically an actor is a "user",
  but it could be a company, a device, or any other entity that needs to be
  classified.

  Using the example of a `User` some groups may be "nobody", "everbody",
  "admin", "staff", etc. Each named group is coupled with a function that
  accepts two arguments (the actor and optional values) and returns a boolean.
  When the return value is `true`, the actor belongs to that group. If the
  value is `false` then they aren't part of the group.

  ## Example

      iex> Flippant.register("nobody", fn(_, _) -> false end)
      :ok

      iex> Flippant.register("everybody", fn(_, _) -> true end)
      :ok

  Group registry is stateful, and global to a Flippant instance. That means an actor
  can be evaulated against every group for every feature check. Be sure to add guards
  if you are mixing different types of actors.

      iex> Flippant.register("enterprise", fn
      ...>               nil, _values -> false
      ...>           %User{}, _values -> false
      ...>   %Company{id: id}, values -> id in values
      ...> end)
      :ok
  """

  @doc """
  Start the registry process.
  """
  @spec start_link() :: Agent.on_start
  def start_link do
    Agent.start_link(fn -> MapSet.new end, name: __MODULE__)
  end

  @doc """
  Clear all registered groups. Groups aren't persisted between app restart,
  making this is most useful for testing.

  ## Example

      iex> Flippant.GroupRegistry.clear()
      :ok
  """
  @spec clear() :: :ok
  def clear do
    Agent.update(__MODULE__, fn(_) -> MapSet.new end)
  end

  @doc """
  Register a new group name and function. The function *must* have an arity of
  2 or it won't be accepted.

  Registering a group with the same name will overwrite the previous group.

  ## Example

      iex> Flippant.GroupRegistry.register("evens",
             fn(actor, _) -> rem(actor.id, 2) == 0 end)
      :ok
  """
  @spec register(binary, fun) :: :ok
  def register(group, fun)
      when is_binary(group)
      when is_function(fun, 2) do
    Agent.update(__MODULE__, &MapSet.put(&1, {group, fun}))
  end

  @doc """
  List all of the registered groups as a map where the keys are the names and
  values are the functions.

  ## Example

      iex> Flippant.GroupRegistry.registered()
      %{"staff" => #Function<20.50752066/0}
  """
  @spec registered() :: map
  def registered() do
    Agent.get(__MODULE__, & Enum.into(&1, %{}))
  end
end
