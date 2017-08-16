defmodule Flippant.Adapter do
  @moduledoc """
  An adapter implemtnation stores the rules that govern features.

  Rules represent individual features along with the group(s) the feature is
  enabled for. For example, "search", "analytics", "super-secret-feature" could
  all be rule names, and they could each be enabled for one or more groups.
  """

  @callback add(binary) :: :ok

  @callback breakdown(map | struct | :all) :: map

  @callback clear() :: :ok

  @callback disable(binary, binary, list(any)) :: :ok

  @callback enable(binary, binary, list(any)) :: :ok

  @callback enabled?(binary, map | struct) :: boolean

  @callback exists?(binary, binary | :any) :: boolean

  @callback features(:all | binary) :: list(binary)

  @callback rename(binary, binary) :: :ok

  @callback remove(binary) :: :ok
end
