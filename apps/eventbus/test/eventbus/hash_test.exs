defmodule Eventbus.HashTest do
  use ExUnit.Case
  alias Eventbus.Hash

  @test_map_name "TEST_MAP"

  setup do
    System.put_env("PROJECT", "foo")
    {:ok, map} = Hash.init(@test_map_name)
    :ok = Hash.reset(map)
    {:ok, map: map}
  end

  test "initialize map" do
      assert Hash.init(@test_map_name) ==
          {:ok, %Hash{name: "foo:hash:#{@test_map_name}"}}
  end

  test "non set key returns empty", context do
    assert Hash.get(context[:map], "key") == {:ok, :not_found}
  end

  test "get returns previously set key", context do
    assert Hash.set(context[:map], "key_1", 5) == :ok
    assert Hash.get(context[:map], "key_1") == {:ok, 5}
    assert Hash.set(context[:map], "key_2", [%{"key" => "val"}]) == :ok
    assert Hash.get(context[:map], "key_2") == {:ok, [%{"key" => "val"}]}
  end

  test "incr_by returns the previous value incremented", context do
    assert Hash.set(context[:map], "key", 5) == :ok
    assert Hash.incr_by(context[:map], "key", 6) == :ok
    assert Hash.get(context[:map], "key") == {:ok, 11}
  end

  test "delete removes previously set value", context do
    assert Hash.set(context[:map], "key", 5) == :ok
    assert Hash.delete(context[:map], "key") == :ok
    assert Hash.get(context[:map], "key") == {:ok, :not_found}
  end

  test "deleting invalid key does not change map", context do
    assert Hash.set(context[:map], "key", 5) == :ok
    assert Hash.delete(context[:map], "key2") == {:ok, :not_found}
    assert Hash.get(context[:map], "key") == {:ok, 5}
  end

end
