defmodule Flippant.RuleRegistry do
  alias Flippant.Adapter

  defdelegate adapter, to: Adapter

  def start_link(options) do
    adapter = Keyword.fetch!(options, :adapter)

    adapter.start_link(options)
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
end
