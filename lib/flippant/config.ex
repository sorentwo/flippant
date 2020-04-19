defmodule Flippant.Config do
  @moduledoc false

  @type t :: %__MODULE__{
          adapter: module(),
          adapter_opts: Keyword.t(),
          name: module(),
          rules: module()
        }

  defstruct adapter: Flippant.Adapter.Memory,
            adapter_opts: [],
            name: Flippant,
            rules: Flippant.Rules.Default

  @spec new(Keyword.t()) :: t()
  def new(opts) when is_list(opts) do
    config = struct!(__MODULE__, opts)

    Map.update!(config, :adapter_opts, &default_adapter_opts(&1, config))
  end

  @spec get(name :: atom()) :: t()
  def get(name), do: :persistent_term.get(name)

  @spec put(name :: atom(), config :: t()) :: :ok
  def put(name, %__MODULE__{} = conf) when is_atom(name), do: :persistent_term.put(name, conf)

  defp default_adapter_opts(opts, %{adapter: adapter}) do
    Keyword.put_new(opts, :name, adapter)
  end
end
