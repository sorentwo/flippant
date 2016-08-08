defmodule Flippant.Adapter.Redis do
  use GenServer

  import Flippant.Rules, only: [enabled_for_actor?: 2]
  import Redix, only: [command: 2, pipeline: 2]
  import Flippant.Serializer, only: [dump: 1, load: 1]

  @feature_key "flippant-features"

  def start_link(options) do
    GenServer.start_link(__MODULE__, options, [name: __MODULE__])
  end

  # Callbacks

  def init(opts) do
    redis_opts = Keyword.get(opts, :redis_opts, [])

    Redix.start_link(redis_opts)
  end

  def handle_cast({:add, feature}, conn) do
    {:ok, _} = command(conn, ["SADD", @feature_key, feature])

    {:noreply, conn}
  end
  def handle_cast({:add, feature, {group, value}}, conn) do
    pipeline(conn, [["SADD", @feature_key, feature],
                    ["HSET", feature, group, dump(value)]])

    {:noreply, conn}
  end

  def handle_cast(:clear, conn) do
    {:ok, _} = command(conn, ["DEL", @feature_key] ++ fetch_features(conn))

    {:noreply, conn}
  end

  def handle_cast({:remove, feature}, conn) do
    pipeline(conn, [["SREM", @feature_key, feature],
                    ["DEL", feature]])

    {:noreply, conn}
  end
  def handle_cast({:remove, feature, group}, conn) do
    with {:ok, _}  <- command(conn, ["HDEL", feature, group]),
         {:ok, []} <- command(conn, ["HGETALL", feature]),
         {:ok, _}  <- command(conn, ["SREM", @feature_key, feature]),
     do: :ok

    {:noreply, conn}
  end

  def handle_call({:breakdown, actor}, _from, conn) do
    features = fetch_features(conn)
    requests = Enum.map(features, &(["HGETALL", &1]))

    {:ok, results} = pipeline(conn, requests)

    breakdown =
      features
      |> Enum.zip(results)
      |> Enum.reduce(%{}, fn({feature, rules}, acc) ->
           Map.put(acc, feature, enabled_for_actor?(decode_rules(rules), actor))
         end)

    {:reply, breakdown, conn}
  end
  def handle_call({:enabled?, feature, actor}, _from, conn) do
    {:ok, rules} = command(conn, ["HGETALL", feature])

    enabled =
      rules
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

    {:ok, results} = pipeline(conn, requests)

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
    {:ok, features} = command(conn, ["SMEMBERS", @feature_key])

    features
  end
end
