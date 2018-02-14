if Code.ensure_loaded(Postgrex) do
  Postgrex.Types.define(Flippant.PostgrexTypes, [], json: Jason)

  defmodule Flippant.Adapter.Postgres do
    @moduledoc """
    This adapter provides Postgres 9.5+ backed rule storage.

    The adapter relies on a table with the following structure:

    * `name` - A `text` or `varchar` column with a unique constraint. The
      adapter makes heavy use of `UPSERT` functionality, which relies on unique
      names.
    * `rules` - A `jsonb` column where rules will be stored. The use of jsonb and
      jsonb specific operators means the Postgres version must be 9.5 or greater.


    In the likely chance that you're using managing a database using Ecto you
    can create a migration to add the `flippant_features` table with the
    following statement (or an equivalent):

        CREATE TABLE IF NOT EXISTS flippant_features (
          name varchar(140) NOT NULL CHECK (name <> ''),
          rules jsonb NOT NULL DEFAULT '{}'::jsonb,
          CONSTRAINT unique_name UNIQUE(name)
        )

    If you prefer you can also use the adapters `setup/0` function to create
    the table automatically.
    """

    use GenServer

    import Postgrex, only: [query!: 3, transaction: 2]
    import Flippant.Rules, only: [enabled_for_actor?: 2]

    @defaults [postgres_opts: [database: "flippant_test"], table: "flippant_features"]

    @doc """
    Starts the Postgres adapter.

    ## Options

      * `:postgres_opts` - Options that can be passed to Postgrex, the underlying
        library used to connect to Postgres. At a minimum the `database` must be set,
        otherwise it will attempt to connect to the `flippant_test` database.
      * `table` - The table where rules will be stored. Defaults to `flippant_features`.
    """
    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    # Callbacks

    def init(opts) do
      {:ok, _} = Application.ensure_all_started(:postgrex)

      opts = Keyword.merge(@defaults, opts)

      {:ok, pid} =
        opts
        |> Keyword.get(:postgres_opts, [])
        |> Keyword.put(:types, Flippant.PostgrexTypes)
        |> Postgrex.start_link()

      {:ok, %{pid: pid, table: Keyword.get(opts, :table)}}
    end

    def handle_cast({:add, feature}, %{pid: pid, table: table} = state) do
      query!(pid, "INSERT INTO #{table} (name) VALUES ($1) ON CONFLICT (name) DO NOTHING", [
        feature
      ])

      {:noreply, state}
    end

    def handle_cast({:add, feature, {group, values}}, %{pid: pid, table: table} = state) do
      query!(
        pid,
        """
        INSERT INTO #{table} AS t (name, rules) VALUES ($1, $2)
        ON CONFLICT (name) DO UPDATE
        SET rules = jsonb_set(t.rules, $3, (COALESCE(t.rules#>$3, '[]'::jsonb) || $4))
        """,
        [feature, %{group => values}, [group], values]
      )

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
      {:ok, _} =
        transaction(pid, fn conn ->
          case query!(conn, "SELECT rules#>$1 FROM #{table} WHERE name = $2 AND rules ? $3", [
                 [group],
                 feature,
                 group
               ]) do
            %{rows: [[old_values]]} ->
              query!(
                conn,
                "UPDATE #{table} SET rules = jsonb_set(rules, $1, $2) WHERE name = $3",
                [[group], old_values -- values, feature]
              )

            _ ->
              nil
          end
        end)

      {:noreply, state}
    end

    def handle_cast({:rename, old_name, new_name}, %{pid: pid, table: table} = state) do
      {:ok, _} =
        transaction(pid, fn conn ->
          query!(conn, "DELETE FROM #{table} WHERE name = $1", [new_name])
          query!(conn, "UPDATE #{table} SET name = $1 WHERE name = $2", [new_name, old_name])
        end)

      {:noreply, state}
    end

    def handle_cast(:setup, %{pid: pid, table: table} = state) do
      query!(
        pid,
        """
        CREATE TABLE IF NOT EXISTS #{table} (
          name varchar(140) NOT NULL CHECK (name <> ''),
          rules jsonb NOT NULL DEFAULT '{}'::jsonb,
          CONSTRAINT unique_name UNIQUE(name)
        )
        """,
        []
      )

      {:noreply, state}
    end

    def handle_call({:breakdown, actor}, _from, %{pid: pid, table: table} = state) do
      breakdown =
        case query!(pid, "SELECT jsonb_object_agg(name, rules) FROM #{table}", []) do
          %{rows: [[object]]} when is_map(object) ->
            Enum.reduce(object, %{}, fn {feature, rules}, acc ->
              Map.put(acc, feature, breakdown_value(rules, actor))
            end)

          _ ->
            %{}
        end

      {:reply, breakdown, state}
    end

    def handle_call({:enabled?, feature, actor}, _from, %{pid: pid, table: table} = state) do
      %{rows: rows} = query!(pid, "SELECT rules FROM #{table} WHERE name = $1", [feature])

      enabled? =
        case rows do
          [[rules]] -> enabled_for_actor?(rules, actor)
          _ -> false
        end

      {:reply, enabled?, state}
    end

    def handle_call({:exists?, feature, :any}, _from, %{pid: pid, table: table} = state) do
      %{rows: [[exists?]]} =
        query!(pid, "SELECT EXISTS (SELECT 1 FROM #{table} WHERE name = $1)", [feature])

      {:reply, exists?, state}
    end

    def handle_call({:exists?, feature, group}, _from, %{pid: pid, table: table} = state) do
      %{rows: [[exists?]]} =
        query!(pid, "SELECT EXISTS (SELECT 1 FROM #{table} WHERE name = $1 AND rules ? $2)", [
          feature,
          group
        ])

      {:reply, exists?, state}
    end

    def handle_call({:features, :all}, _from, %{pid: pid, table: table} = state) do
      %{rows: rows} = query!(pid, "SELECT name FROM #{table} ORDER BY name ASC", [])

      {:reply, List.flatten(rows), state}
    end

    def handle_call({:features, group}, _from, %{pid: pid, table: table} = state) do
      %{rows: rows} =
        query!(pid, "SELECT name FROM #{table} WHERE rules ? $1 ORDER BY name ASC", [group])

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
