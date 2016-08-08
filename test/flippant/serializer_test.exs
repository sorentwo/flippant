defmodule Flippant.SerializerTest do
  use ExUnit.Case, async: true

  alias Flippant.Serializer
  alias Flippant.Serializer.Term

  describe "serializer/0" do
    test "defaults to term storage" do
      assert Serializer.serializer == Term
    end

    test "uses the configured serializer" do
      defmodule Custom do
      end

      try do
        Application.put_env(:flippant, :serializer, Custom)

        assert Serializer.serializer == Custom
      after
        Application.delete_env(:flippant, :serializer)
      end
    end
  end

  describe "dumping and loading" do
    test "values are serialized and deserialized using the serializer" do
      value = %{a: 1}
      dumped = Serializer.dump(value)
      loaded = Serializer.load(dumped)

      assert dumped != value
      assert loaded == value
    end
  end
end
