defmodule Flippant do
  use Application

  alias Flippant.{GroupRegistry, RuleRegistry}

  @doc """
  Starts the Flippant application and supervision tree.
  """
  def start(_, _) do
    import Supervisor.Spec

    flippant_opts = Application.get_all_env(:flippant)

    children = [
      worker(GroupRegistry, []),
      worker(RuleRegistry, [flippant_opts])
    ]

    opts = [strategy: :one_for_one, name: Flippant.Supervisor]

    Supervisor.start_link(children, opts)
  end

  defdelegate add(feature), to: RuleRegistry
  defdelegate breakdown(), to: RuleRegistry
  defdelegate breakdown(actor), to: RuleRegistry
  defdelegate disable(feature, group), to: RuleRegistry
  defdelegate enable(feature, group), to: RuleRegistry
  defdelegate enable(feature, group, values), to: RuleRegistry
  defdelegate enabled?(feature, actor), to: RuleRegistry
  defdelegate exists?(feature), to: RuleRegistry
  defdelegate exists?(feature, group), to: RuleRegistry
  defdelegate features(), to: RuleRegistry
  defdelegate features(group), to: RuleRegistry
  defdelegate register(group, fun), to: GroupRegistry
  defdelegate registered(), to: GroupRegistry
  defdelegate remove(feature), to: RuleRegistry

  @doc """
  Purge all of the registered groups and features. This is particularly useful
  in testing when you want to reset to a clean slate after a test.

  ## Example

      iex> Flippant.clear()
      :ok
  """
  @spec clear() :: :ok
  def clear() do
    clear(:groups)
    clear(:features)

    :ok
  end

  @doc """
  Purge all of the registered groups or features.

  ## Example

  Clear only features:

      iex> Flippant.clear(:features)
      :ok

  Clear only groups:

      iex> Flippant.clear(:groups)
      :ok
  """
  @spec clear(:features | :groups) :: :ok
  def clear(:features), do: RuleRegistry.clear
  def clear(:groups),   do: GroupRegistry.clear
end
