defmodule Flippant.SerializerTest do
  use ExUnit.Case, async: true

  alias Flippant.Serializer
  alias Flippant.Serializer.Term

  describe "serializer/0" do
    test "defaults to term storage" do
      assert Serializer.serializer == Term
    end

    test "uses the configured serializer" do
      on_exit fn -> Application.delete_env(:flippant, :serializer) end

      Application.put_env(:flippant, :serializer, :custom)

      assert Serializer.serializer == :custom
    end
  end

  describe "dumping and loading" do
    test "values are serialized and deserialized using the serializer" do
      value = %{a: 1, b: 2}
      dumped = Serializer.dump(value)
      loaded = Serializer.load(dumped)

      assert dumped != value
      assert loaded == value
    end
  end
end
