defmodule Flippant.Adapter.Memory do
  use GenServer

  import Flippant.Rules, only: [enabled_for_actor?: 2]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [name: __MODULE__])
  end

  # Callbacks

  def init(_opts) do
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
      [{_, rules}] -> :ets.insert(table, {feature, merge_rules(rule, rules)})
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
  def handle_cast({:remove, feature, group, []}, table) do
    case :ets.lookup(table, feature) do
      [{_, rules}] -> :ets.insert(table, {feature, without_group(rules, group)})
                 _ -> true
    end

    {:noreply, table}
  end
  def handle_cast({:remove, feature, group, values}, table) do
    case :ets.lookup(table, feature) do
      [{_, rules}] -> :ets.insert(table, {feature, diff_rules({group, values}, rules)})
                 _ -> true
    end

    {:noreply, table}
  end

  def handle_cast({:rename, old_name, new_name}, table) do
    with [{_, rules}] <- :ets.lookup(table, old_name),
         true <- :ets.insert(table, {new_name, rules}),
         true <- :ets.delete(table, old_name),
     do: true

    {:noreply, table}
  end

  def handle_call({:breakdown, actor}, _from, table) do
    fun = fn({feature, rules}), acc ->
      Map.put(acc, feature, breakdown_value(rules, actor))
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

  def handle_call({:exists?, feature, group}, _from, table) do
    exists = case :ets.lookup(table, feature) do
      [{_, rules}] -> contains_group?(rules, group)
                [] -> false
    end

    {:reply, exists, table}
  end

  def handle_call({:features, group}, _from, table) do
    {:reply, get_features(table, group), table}
  end

  # Helpers

  defp breakdown_value(rules, :all) do
    Enum.into(rules, %{})
  end
  defp breakdown_value(rules, actor) do
    enabled_for_actor?(rules, actor)
  end

  defp contains_group?(_, :any) do
    true
  end
  defp contains_group?(rules, group) do
    Enum.any?(rules, &(elem(&1, 0) == group))
  end

  def change_values({group, values}, rules, fun) do
    mvalues = case Enum.find(rules, &(elem(&1, 0) == group)) do
      {_, rvalues} -> fun.(rvalues, values)
                 _ -> values
    end

    List.keystore(rules, group, 0, {group, Enum.sort(mvalues)})
  end

  defp diff_rules(rule, rules) do
    change_values(rule, rules, fn (old, new) -> old -- new end)
  end

  defp merge_rules(rule, rules) do
    change_values(rule, rules, fn (old, new) -> new ++ old end)
  end

  defp get_features(table, :all) do
    table
    |> :ets.tab2list
    |> Enum.map(&(elem(&1, 0)))
  end
  defp get_features(table, group) do
    table
    |> :ets.tab2list
    |> Enum.filter(fn({_, rules}) -> Enum.any?(rules, &(elem(&1, 0) == group)) end)
    |> Enum.map(&(elem(&1, 0)))
  end

  defp without_group(rules, group) do
    List.keydelete(rules, group, 0)
  end
end
