defmodule Flippant.Adapter.Memory do
  use GenServer

  import Flippant.Rules, only: [enabled_for_actor?: 2]

  def start_link(options) do
    GenServer.start_link(__MODULE__, options, [name: __MODULE__])
  end

  # Callbacks

  def init(_options) do
    {:ok, :ets.new(:features, [read_concurrency: true])}
  end

  def handle_cast({:add, feature}, table) do
    case :ets.lookup(table, feature) do
      [] -> :ets.insert(table, {feature, []})
       _ -> true
    end

    {:noreply, table}
  end
  def handle_cast({:add, feature, rule}, table) do
    case :ets.lookup(table, feature) do
      [{_, rules}] -> :ets.insert(table, {feature, [rule | rules]})
      [] -> :ets.insert(table, {feature, [rule]})
    end

    {:noreply, table}
  end
  def handle_cast(:clear, table) do
    :ets.delete_all_objects(table)

    {:noreply, table}
  end
  def handle_cast({:remove, feature}, table) do
    :ets.delete(table, feature)

    {:noreply, table}
  end
  def handle_cast({:remove, feature, group}, table) do
    case :ets.lookup(table, feature) do
      [{_, rules}] -> :ets.insert(table, {feature, without_group(rules, group)})
                 _ -> true
    end

    {:noreply, table}
  end

  def handle_call({:breakdown, actor}, _from, table) do
    fun = fn {feature, rules}, acc ->
      Map.put(acc, feature, enabled_for_actor?(rules, actor))
    end

    {:reply, :ets.foldl(fun, %{}, table), table}
  end
  def handle_call({:enabled?, feature, actor}, _from, table) do
    enabled = case :ets.lookup(table, feature) do
      [{_, rules}] -> enabled_for_actor?(rules, actor)
                [] -> false
    end

    {:reply, enabled, table}
  end
  def handle_call({:features, group}, _from, table) do
    {:reply, get_features(table, group), table}
  end

  # Helpers

  defp get_features(table, :all) do
    table
    |> :ets.tab2list
    |> Enum.map(&(elem &1, 0))
  end
  defp get_features(table, group) do
    table
    |> :ets.tab2list
    |> Enum.filter(fn {_, rules} -> Enum.any?(rules, &(elem(&1, 0) == group)) end)
    |> Enum.map(&(elem &1, 0))
  end

  defp without_group(rules, to_remove) do
    Enum.reject(rules, fn {group, _} -> group == to_remove end)
  end
end
