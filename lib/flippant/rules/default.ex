defmodule Flippant.Rules.Default do
  @moduledoc """
  The default rules defines `nobody` and `everybody`.
  """

  alias Flippant.Rules

  @behaviour Rules

  @impl Rules
  def enabled?("everybody", _enabled_for, _actor), do: true

  def enabled?("nobody", _enabled_for, _actor), do: false

  def enabled?(_group, _enabled_for, _actor), do: false
end
