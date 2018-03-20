defmodule Flippant.Serializer.Term do
  @moduledoc """
  Serialize values using Erlang's binary term storage.
  """

  @behaviour Flippant.Serializer

  @doc """
  Serialize data using `term_to_binary/1`.
  """
  @impl Flippant.Serializer
  def encode!(value), do: :erlang.term_to_binary(value)

  @doc """
  Deserialize data using `binary_to_term/1`.
  """
  @impl Flippant.Serializer
  def decode!(value), do: :erlang.binary_to_term(value)
end
