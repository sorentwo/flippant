if Code.ensure_loaded?(Redix) do
  defmodule Flippant.Adapter.Redis do
    @moduledoc """
    This module provides Redis backed rule storage.
    """

    use GenServer

    import Flippant.Rules, only: [enabled_for_actor?: 2]
    import Flippant.Serializer, only: [dump: 1, load: 1]
    import Redix, only: [command!: 2]

    @default_set_key "flippant-features"

    @doc """
    Starts the Redis adapter.

    # Options

      * `:redis_opts` - Options that can be passed to Redix, the underlying
        library used to connect to Redis.
      * `:set_key` - The Redis key where rules will be stored. Defaults to
        `"flippant-features"`.
    """
    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts, [name: __MODULE__])
    end

    # Callbacks

    def init(opts) do
      {:ok, conn} =
        opts
        |> Keyword.get(:redis_opts, [])
        |> parse_opts_and_connect()

      set_key = Keyword.get(opts, :set_key, @default_set_key)

      {:ok, %{conn: conn, set_key: set_key}}
    end

    def handle_cast({:add, feature}, %{conn: conn, set_key: set_key} = state) do
      command!(conn, ["SADD", set_key, feature])

      {:noreply, state}
    end
    def handle_cast({:add, feature, {group, values}}, %{conn: conn, set_key: set_key} = state) do
      old_values = command!(conn, ["HGET", feature, group])
      new_values = merge_values(old_values, values)

      pipeline!(conn, [["SADD", set_key, feature],
                      ["HSET", feature, group, new_values]])

      {:noreply, state}
    end

    def handle_cast(:clear, %{conn: conn, set_key: set_key} = state) do
      command!(conn, ["DEL", set_key] ++ fetch_features(state))

      {:noreply, state}
    end

    def handle_cast({:remove, feature}, %{conn: conn, set_key: set_key} = state) do
      pipeline!(conn, [["SREM", set_key, feature],
                      ["DEL", feature]])

      {:noreply, state}
    end
    def handle_cast({:remove, feature, group, []}, %{conn: conn, set_key: set_key} = state) do
      with _count <- command!(conn, ["HDEL", feature, group]),
               [] <- command!(conn, ["HGETALL", feature]),
           _count <- command!(conn, ["SREM", set_key, feature]),
       do: :ok

      {:noreply, state}
    end
    def handle_cast({:remove, feature, group, values}, %{conn: conn} = state) do
      old_values = command!(conn, ["HGET", feature, group])
      new_values = diff_values(old_values, values)

      command!(conn, ["HSET", feature, group, new_values])

      {:noreply, state}
    end

    def handle_cast({:rename, old_name, new_name}, %{conn: conn, set_key: set_key} = state) do
      pipeline!(conn, [["WATCH", old_name, new_name],
                       ["SREM", set_key, old_name],
                       ["SADD", set_key, new_name],
                       ["RENAME", old_name, new_name]])

      {:noreply, state}
    end

    def handle_call({:breakdown, actor}, _from, %{conn: conn} = state) do
      features = fetch_features(state)
      requests = Enum.map(features, &(["HGETALL", &1]))
      results  = pipeline!(conn, requests)

      breakdown =
        features
        |> Enum.zip(results)
        |> Enum.reduce(%{}, fn({feature, rules}, acc) ->
             Map.put(acc, feature, breakdown_value(decode_rules(rules), actor))
           end)

      {:reply, breakdown, state}
    end

    def handle_call({:enabled?, feature, actor}, _from, %{conn: conn} = state) do
      enabled =
        conn
        |> command!(["HGETALL", feature])
        |> decode_rules()
        |> enabled_for_actor?(actor)

      {:reply, enabled, state}
    end

    def handle_call({:exists?, feature, :any}, _from, %{conn: conn, set_key: set_key} = state) do
      enabled = command!(conn, ["SISMEMBER", set_key, feature]) == 1

      {:reply, enabled, state}
    end
    def handle_call({:exists?, feature, group}, _from, %{conn: conn} = state) do
      enabled = command!(conn, ["HEXISTS", feature, group]) == 1

      {:reply, enabled, state}
    end

    def handle_call({:features, :all}, _from, state) do
      {:reply, fetch_features(state), state}
    end
    def handle_call({:features, group}, _from, %{conn: conn} = state) do
      features = fetch_features(state)
      requests = Enum.map(features, &(["HEXISTS", &1, group]))
      results  = pipeline!(conn, requests)

      features =
        features
        |> Enum.zip(results)
        |> Enum.filter(& elem(&1, 1) == 1)
        |> Enum.map(& elem(&1, 0))

      {:reply, features, state}
    end

    # Helpers

    defp breakdown_value(rules, :all) do
      Enum.into(rules, %{})
    end
    defp breakdown_value(rules, actor) do
      enabled_for_actor?(rules, actor)
    end

    defp decode_rules(rules) do
      rules
      |> Enum.chunk(2)
      |> Enum.map(fn [key, value] -> {key, load(value)} end)
      |> Enum.into(%{})
    end

    defp fetch_features(%{conn: conn, set_key: set_key}) do
      conn
      |> command!(["SMEMBERS", set_key])
      |> Enum.sort
    end

    defp diff_values(nil, new_values) do
      dump(new_values)
    end
    defp diff_values(old_values, new_values) do
      old_values
      |> load()
      |> Kernel.--(new_values)
      |> dump()
    end

    defp merge_values(nil, new_values) do
      dump(new_values)
    end
    defp merge_values(old_values, []) do
      old_values
    end
    defp merge_values(old_values, new_values) do
      old_values
      |> load()
      |> Kernel.++(new_values)
      |> Enum.sort()
      |> dump()
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
end
