defmodule Flippant.Adapter.RedisTest do
  use ExUnit.Case, async: true

  alias Flippant.Adapter.Redis

  describe "start_link/1" do
    test "url options are extracted and passed to redix" do
      assert {:ok, _pid} = Redis.init(redis_opts: [url: "redis://localhost:6379/1"])

      assert_raise Redix.URI.URIError, fn ->
        Redis.init(redis_opts: [url: "NOTAREALURL"])
      end
    end
  end
end
