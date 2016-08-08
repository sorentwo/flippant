defmodule Flippant.GroupRegistry do
  def start_link do
    Agent.start_link(fn -> MapSet.new end, name: __MODULE__)
  end

  def clear do
    Agent.update(__MODULE__, fn(_) -> MapSet.new end)
  end

  def register(group, fun)
      when is_binary(group)
      when is_function(fun, 2) do
    Agent.update(__MODULE__, &MapSet.put(&1, {group, fun}))
  end

  def registered do
    Agent.get(__MODULE__, & Enum.into(&1, %{}))
  end
end
