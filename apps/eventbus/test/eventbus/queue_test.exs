defmodule Eventbus.TestQueue do

  use ExUnit.Case
  alias Eventbus.Queue

  @test_queue_name "TEST_QUEUE"

  setup do
    System.put_env("PROJECT", "foo")
    {:ok, queue} = Queue.init(@test_queue_name)
    :ok = Queue.reset(queue)
    {:ok, queue: queue}
  end

  test "initialize queue" do
      assert Queue.init(@test_queue_name) ==
          {:ok, %Queue{name: "foo:queue:#{@test_queue_name}"}}
  end

  test "new queue is empty", context do
    assert Queue.count(context[:queue]) == {:ok, 0}
  end

  test "poping an empty queue returns empty", context  do
    assert Queue.pop(context[:queue]) == {:ok, :empty}
  end

  test "insert value in queue", context do
    assert Queue.push(context[:queue], "first") == :ok
    assert Queue.count(context[:queue]) == {:ok, 1}
  end

  test "removing value from queue returns old item first", context do
    assert Queue.push(context[:queue], "first") == :ok
    assert Queue.push(context[:queue], "second") == :ok
    assert Queue.count(context[:queue]) == {:ok, 2}
    assert Queue.pop(context[:queue]) == {:ok, "first"}
    assert Queue.count(context[:queue]) == {:ok, 1}
    assert Queue.pop(context[:queue]) == {:ok, "second"}
    assert Queue.count(context[:queue]) == {:ok, 0}
  end

end
