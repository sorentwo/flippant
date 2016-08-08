defmodule Flippant.Adapter do
  @moduledoc """
  An adapter is a module that stores rules. Adapters should be stateful and run
  in their own process. The built in adapters are all GenServers, and therefor
  implement the GenServer behaviour.

  For a breakdown of the expected calls and casts see Flippant.RuleRegistry
  """

  @doc """
  Retrieve the `pid` of the configured adapter process. It is expected that the
  adapter has been started.
  """
  @spec adapter() :: pid
  def adapter do
    :flippant
    |> Application.get_env(:adapter)
    |> Process.whereis()
  end
end
