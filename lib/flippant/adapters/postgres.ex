if Code.ensure_loaded(Postgrex) do
  Postgrex.Types.define(Flippant.PostgrexTypes, [], json: Poison)

  defmodule Flippant.Adapter.Postgres do
    # CREATE TABLE flippant_features (
    #   name varchar(140) NOT NULL CHECK (name <> ''),
    #   rules json NOT NULL DEFAULT '{}'::json,
    #   CONSTRAINT unique_name UNIQUE(name)
    # );

    use GenServer

    import Postgrex, only: [query!: 3, transaction: 2]
    import Flippant.Rules, only: [enabled_for_actor?: 2]

    @default_table "flippant_features"

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts, [name: __MODULE__])
    end

    # Callbacks

    def init(opts) do
      {:ok, _apps} = Application.ensure_all_started(:postgrex)

      {:ok, pid} =
        opts
        |> Keyword.get(:postgres_opts, [])
        |> Keyword.put(:database, "flippant_test")
        |> Keyword.put(:types, Flippant.PostgrexTypes)
        |> Postgrex.start_link()

      table = Keyword.get(opts, :table, @default_table)

      {:ok, %{pid: pid, table: table}}
    end

    def handle_cast({:add, feature}, %{pid: pid, table: table} = state) do
      query!(pid, "INSERT INTO #{table} (name) VALUES ($1) ON CONFLICT (name) DO NOTHING", [feature])

      {:noreply, state}
    end
    def handle_cast({:add, feature, {group, values}}, %{pid: pid, table: table} = state) do
      query!(pid,
             """
             INSERT INTO #{table} AS t (name, rules) VALUES ($1, $2)
             ON CONFLICT (name) DO UPDATE
             SET rules = jsonb_set(t.rules, $3, (COALESCE(t.rules#>$3, '[]'::jsonb) || $4))
             """,
             [feature, %{group => values}, [group], values])

      {:noreply, state}
    end

    def handle_cast(:clear, %{pid: pid, table: table} = state) do
      query!(pid, "TRUNCATE #{table} RESTART IDENTITY", [])

      {:noreply, state}
    end

    def handle_cast({:remove, feature}, %{pid: pid, table: table} = state) do
      query!(pid, "DELETE FROM #{table} WHERE name = $1", [feature])

      {:noreply, state}
    end
    def handle_cast({:remove, feature, group, []}, %{pid: pid, table: table} = state) do
      query!(pid, "UPDATE #{table} SET rules = rules - $1 WHERE name = $2", [group, feature])

      {:noreply, state}
    end
    def handle_cast({:remove, feature, group, values}, %{pid: pid, table: table} = state) do
      {:ok, _} = transaction(pid, fn conn ->
        case query!(conn,
                    "SELECT rules#>$1 FROM #{table} WHERE name = $2 AND rules ? $3",
                    [[group], feature, group]) do
          %{rows: [[old_values]]} ->
            query!(conn,
                   "UPDATE #{table} SET rules = jsonb_set(rules, $1, $2) WHERE name = $3",
                   [[group], old_values -- values, feature])
          _ ->
            nil
        end
      end)

      {:noreply, state}
    end

    def handle_cast({:rename, old_name, new_name}, %{pid: pid, table: table} = state) do
      {:ok, _} = transaction(pid, fn conn ->
        query!(conn, "DELETE FROM #{table} WHERE name = $1", [new_name])
        query!(conn, "UPDATE #{table} SET name = $1 WHERE name = $2", [new_name, old_name])
      end)

      {:noreply, state}
    end

    def handle_call({:breakdown, actor}, _from, %{pid: pid, table: table} = state) do
      breakdown = case query!(pid, "SELECT jsonb_object_agg(name, rules) FROM #{table}", []) do
        %{rows: [[object]]} when is_map(object) ->
          Enum.reduce(object, %{}, fn({feature, rules}, acc) ->
            Map.put(acc, feature, breakdown_value(rules, actor))
          end)
        _ -> %{}
      end

      {:reply, breakdown, state}
    end

    def handle_call({:enabled?, feature, actor}, _from, %{pid: pid, table: table} = state) do
      %{rows: rows} = query!(pid, "SELECT rules FROM #{table} WHERE name = $1", [feature])

      enabled? = case rows do
        [[rules]] -> enabled_for_actor?(rules, actor)
        _ -> false
      end

      {:reply, enabled?, state}
    end

    def handle_call({:exists?, feature, :any}, _from, %{pid: pid, table: table} = state) do
      %{rows: [[exists?]]} = query!(pid, "SELECT EXISTS (SELECT 1 FROM #{table} WHERE name = $1)", [feature])

      {:reply, exists?, state}
    end
    def handle_call({:exists?, feature, group}, _from, %{pid: pid, table: table} = state) do
      %{rows: [[exists?]]} = query!(pid, "SELECT EXISTS (SELECT 1 FROM #{table} WHERE name = $1 AND rules ? $2)", [feature, group])

      {:reply, exists?, state}
    end

    def handle_call({:features, :all}, _from, %{pid: pid, table: table} = state) do
      %{rows: rows} = query!(pid, "SELECT name FROM #{table} ORDER BY name ASC", [])

      {:reply, List.flatten(rows), state}
    end
    def handle_call({:features, group}, _from, %{pid: pid, table: table} = state) do
      %{rows: rows} = query!(pid, "SELECT name FROM #{table} WHERE rules ? $1 ORDER BY name ASC", [group])

      {:reply, List.flatten(rows), state}
    end

    # Helpers

    defp breakdown_value(rules, :all) do
      Enum.into(rules, %{})
    end
    defp breakdown_value(rules, actor) do
      enabled_for_actor?(rules, actor)
    end
  end
end
