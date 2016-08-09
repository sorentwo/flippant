defmodule Flippant.Adapter.Redis do
  use GenServer

  import Flippant.Rules, only: [enabled_for_actor?: 2]
  import Flippant.Serializer, only: [dump: 1, load: 1]
  import Redix, only: [command!: 2]

  @feature_key "flippant-features"

  def start_link(options) do
    GenServer.start_link(__MODULE__, options, [name: __MODULE__])
  end

  # Callbacks

  def init(opts) do
    redis_opts = Keyword.get(opts, :redis_opts, [])

    parse_opts_and_connect(redis_opts)
  end

  def handle_cast({:add, feature}, conn) do
    command!(conn, ["SADD", @feature_key, feature])

    {:noreply, conn}
  end
  def handle_cast({:add, feature, {group, value}}, conn) do
    pipeline!(conn, [["SADD", @feature_key, feature],
                    ["HSET", feature, group, dump(value)]])

    {:noreply, conn}
  end

  def handle_cast(:clear, conn) do
    command!(conn, ["DEL", @feature_key] ++ fetch_features(conn))

    {:noreply, conn}
  end

  def handle_cast({:remove, feature}, conn) do
    pipeline!(conn, [["SREM", @feature_key, feature],
                    ["DEL", feature]])

    {:noreply, conn}
  end
  def handle_cast({:remove, feature, group}, conn) do
    with _count <- command!(conn, ["HDEL", feature, group]),
             [] <- command!(conn, ["HGETALL", feature]),
         _count <- command!(conn, ["SREM", @feature_key, feature]),
     do: :ok

    {:noreply, conn}
  end

  def handle_call({:breakdown, actor}, _from, conn) do
    features = fetch_features(conn)
    requests = Enum.map(features, &(["HGETALL", &1]))
    results  = pipeline!(conn, requests)

    breakdown =
      features
      |> Enum.zip(results)
      |> Enum.reduce(%{}, fn({feature, rules}, acc) ->
           Map.put(acc, feature, enabled_for_actor?(decode_rules(rules), actor))
         end)

    {:reply, breakdown, conn}
  end
  def handle_call({:enabled?, feature, actor}, _from, conn) do
    enabled =
      conn
      |> command!(["HGETALL", feature])
      |> decode_rules()
      |> enabled_for_actor?(actor)

    {:reply, enabled, conn}
  end

  def handle_call({:features, :all}, _from, conn) do
    {:reply, fetch_features(conn), conn}
  end
  def handle_call({:features, group}, _from, conn) do
    features = fetch_features(conn)
    requests = Enum.map(features, &(["HEXISTS", &1, group]))
    results  = pipeline!(conn, requests)

    features =
      features
      |> Enum.zip(results)
      |> Enum.filter_map(&(elem(&1, 1) == 1), &(elem(&1, 0)))

    {:reply, features, conn}
  end

  # Helpers

  defp decode_rules(rules) do
    rules
    |> Enum.chunk(2)
    |> Enum.map(fn [key, value] -> {key, load(value)} end)
    |> Enum.into(%{})
  end

  defp fetch_features(conn) do
    conn
    |> command!(["SMEMBERS", @feature_key])
  end

  defp pipeline!(_conn, []) do
    []
  end
  defp pipeline!(conn, requests) do
    Redix.pipeline!(conn, requests)
  end

  defp parse_opts_and_connect(opts) do
    if url = Keyword.get(opts, :url) do
      Redix.start_link(url, Keyword.delete(opts, :url))
    else
      Redix.start_link(opts)
    end
  end
end
