defmodule Flippant.Adapter.Redis do
  use GenServer

  import Flippant.Rules, only: [enabled_for_actor?: 2]

  @feature_key "flippant-features"

  def start_link(options) do
    GenServer.start_link(__MODULE__, options, [name: __MODULE__])
  end

  # Callbacks

  def init(_options) do
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
          Map.put(acc, feature, enabled_for_actor?(decode_rules(rules), actor))
         end)

    {:reply, breakdown, conn}
  end
  def handle_call({:enabled?, feature, actor}, _from, conn) do
    {:ok, rules} = Redix.command(conn, ["HGETALL", feature])

    enabled =
      rules
      |> decode_rules()
      |> enabled_for_actor?(actor)

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

  defp decode_rules(rules) do
    rules
    |> Enum.chunk(2)
    |> Enum.map(fn [key, val] -> {key, :erlang.binary_to_term(val)} end)
    |> Enum.into(%{})
  end
end
