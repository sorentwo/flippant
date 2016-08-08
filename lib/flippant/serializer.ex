defmodule Flippant.Serializer do
  @moduledoc """
  Rules may be stored with arbitrary values. For some storage environments,
  like Redis, the values must be serialized to and from a binary format.

  By default all load and dump operations use Erlang's binary to term
  conversion. This isn't especially portable, or readable, so it can be
  overridden within your app's configuration.

  ## Example

      Application.put_env(:flippant, serializer: MySerializer)
  """

  @callback dump(value :: any) :: binary
  @callback load(value :: binary) :: any

  alias Flippant.Serializer.Term

  @doc """
  Delegates dumping a value to the configured serializer.
  """
  @spec dump(any) :: binary
  def dump(value), do: serializer().dump(value)

  @doc """
  Delegates loading a value with the configured serializer.
  """
  @spec load(binary) :: any
  def load(value), do: serializer().load(value)

  @doc """
  Get the currently configured serializer module. Defaults to `Term` storage.
  """
  @spec serializer() :: module
  def serializer do
    Application.get_env(:flippant, :serializer, Term)
  end
end
