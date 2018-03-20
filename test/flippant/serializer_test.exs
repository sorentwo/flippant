defmodule Flippant.SerializerTest do
  use ExUnit.Case, async: true

  alias Flippant.Serializer
  alias Flippant.Serializer.Term

  setup do
    on_exit(fn -> Application.put_env(:flippant, :serializer, Term) end)

    :ok
  end

  describe "serializer/0" do
    test "defaults to term storage" do
      assert Serializer.serializer() == Term
    end

    test "uses the configured serializer" do
      Application.put_env(:flippant, :serializer, :custom)

      assert Serializer.serializer() == :custom
    end
  end

  describe "dumping and loading" do
    test "values are serialized and deserialized using the serializer" do
      value = %{a: 1, b: 2}
      dumped = Serializer.encode!(value)
      loaded = Serializer.decode!(dumped)

      assert dumped != value
      assert loaded == value
    end
  end
end
