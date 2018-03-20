defmodule Flippant.Serializer do
  @moduledoc """
  Rules may be stored with arbitrary values. For some storage environments,
  like Redis, the values must be serialized to and from a binary format.

  By default all load and dump operations use Erlang's binary to term
  conversion. This isn't especially portable, or readable, so it can be
  overridden within your app's configuration.

  ## Examples

      Application.put_env(:flippant, serializer: MySerializer)
  """

  @callback encode!(value :: any()) :: binary()
  @callback decode!(value :: binary()) :: any()

  @doc """
  Delegates dumping a value to the configured serializer.
  """
  @spec encode!(any()) :: binary() | no_return()
  def encode!(value), do: serializer().encode!(value)

  @doc """
  Delegates loading a value with the configured serializer.
  """
  @spec decode!(binary()) :: any() | no_return()
  def decode!(value), do: serializer().decode!(value)

  @doc """
  Get the currently configured serializer module. Defaults to `Term` storage.
  """
  @spec serializer() :: module()
  def serializer do
    Application.fetch_env!(:flippant, :serializer)
  end
end
