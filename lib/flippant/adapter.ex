defmodule Flippant.Adapter do
  def adapter do
    :flippant
    |> Application.get_env(:adapter)
    |> Process.whereis()
  end
end
