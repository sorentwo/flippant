defmodule Flippant.Registry do
  def start_link do
    Agent.start_link(fn -> MapSet.new end, name: __MODULE__)
  end

  def clear do
    Agent.update(__MODULE__, fn(_) -> MapSet.new end)
  end

  def register(group, fun) when is_atom(group) do
    register(Atom.to_string(group), fun)
  end
  def register(group, fun) do
    Agent.update(__MODULE__, &MapSet.put(&1, {group, fun}))
  end

  def registered do
    Agent.get(__MODULE__, &(Enum.into(&1, %{})))
  end
end
