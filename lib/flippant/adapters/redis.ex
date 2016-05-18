defmodule Flippant.Adapter.Redis do
  use GenServer

  @feature_key "flippant-features"

  @behaviour Flippant.Adapter

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def add(feature) when is_binary(feature) do
    GenServer.cast(adapter, {:add, feature})
  end

  def breakdown(actor) do
    GenServer.call(adapter, {:breakdown, actor})
  end

  def clear do
    GenServer.cast(adapter, :clear)
  end

  def disable(feature, group)
      when is_binary(feature)
      when is_binary(group) do

    GenServer.cast(adapter, {:remove, feature, group})
  end

  def enable(feature, group, values \\ true)
      when is_binary(feature)
      when is_binary(group) do

    GenServer.cast(adapter, {:add, feature, {group, values}})
  end

  def enabled?(feature, actor) when is_binary(feature) do
    GenServer.call(adapter, {:enabled?, feature, actor})
  end

  def features(group \\ :all) do
    GenServer.call(adapter, {:features, group})
  end

  def remove(feature) when is_binary(feature) do
    GenServer.cast(adapter, {:remove, feature})
  end

  # Callbacks

  def init(:ok) do
    Redix.start_link
  end

  def handle_cast({:add, feature}, conn) do
    {:ok, _} = Redix.command(conn, ["SADD", @feature_key, feature])

    {:noreply, conn}
  end
  def handle_cast({:add, feature, {group, values}}, conn) do
    values = :erlang.term_to_binary(values)

    Redix.pipeline(conn, [["SADD", @feature_key, feature],
                          ["HSET", feature, group, values]])

    {:noreply, conn}
  end

  def handle_cast(:clear, conn) do
    with {:ok, features} <- Redix.command(conn, ["SMEMBERS", @feature_key]),
         {:ok, _count}   <- Redix.command(conn, ["DEL", @feature_key] ++ features),
     do: :ok

    {:noreply, conn}
  end

  def handle_cast({:remove, feature}, conn) do
    Redix.pipeline(conn, [["SREM", @feature_key, feature],
                          ["DEL", feature]])

    {:noreply, conn}
  end
  def handle_cast({:remove, feature, group}, conn) do
    with {:ok, _}  <- Redix.command(conn, ["HDEL", feature, group]),
         {:ok, []} <- Redix.command(conn, ["HGETALL", feature]),
         {:ok, _}  <- Redix.command(conn, ["SREM", @feature_key, feature]),
     do: :ok

    {:noreply, conn}
  end

  def handle_call({:breakdown, actor}, _from, conn) do
    {:ok, features} = Redix.command(conn, ["SMEMBERS", @feature_key])

    requests = Enum.map(features, & ["HGETALL", &1])

    {:ok, results} = Redix.pipeline(conn, requests)

    breakdown =
      features
      |> Enum.zip(results)
      |> Enum.reduce(%{}, fn({feature, rules}, acc) ->
          Map.put(acc, feature, matches_any_rules?(decode_rules(rules), actor))
         end)

    {:reply, breakdown, conn}
  end
  def handle_call({:enabled?, feature, actor}, _from, conn) do
    {:ok, rules} = Redix.command(conn, ["HGETALL", feature])

    enabled =
      rules
      |> decode_rules()
      |> matches_any_rules?(actor)

    {:reply, enabled, conn}
  end

  def handle_call({:features, :all}, _from, conn) do
    {:ok, features} = Redix.command(conn, ["SMEMBERS", @feature_key])

    {:reply, features, conn}
  end
  def handle_call({:features, group}, _from, conn) do
    {:ok, features} = Redix.command(conn, ["SMEMBERS", @feature_key])

    requests = Enum.map(features, & ["HEXISTS", &1, group])

    {:ok, results} = Redix.pipeline(conn, requests)

    features =
      features
      |> Enum.zip(results)
      |> Enum.reject(& elem(&1, 1) == 0)
      |> Enum.map(& elem(&1, 0))

    {:reply, features, conn}
  end

  # Helpers

  defp adapter do
    Process.whereis(__MODULE__)
  end

  defp decode_rules(rules) do
    rules
    |> Enum.chunk(2)
    |> Enum.map(fn [key, val] -> {key, :erlang.binary_to_term(val)} end)
    |> Enum.into(%{})
  end

  # TODO: This is identical, extract it
  defp matches_any_rules?(rules, actor) do
    registered = Flippant.registered

    Enum.any?(rules, fn {group, values} ->
      if fun = Map.get(registered, group) do
        apply(fun, [actor, values])
      end
    end)
  end
end
