defmodule Eventbus.PriorityQueueTest do
  use ExUnit.Case
  alias Eventbus.PriorityQueue

  @test_queue_name "TEST_QUEUE"

  setup do
    System.put_env("PROJECT", "foo")
    {:ok, queue} = PriorityQueue.init(@test_queue_name)
    :ok = PriorityQueue.reset(queue)
    {:ok, queue: queue}
  end

  test "initialize priority queue" do
      assert PriorityQueue.init(@test_queue_name) ==
          {:ok, %PriorityQueue{name: "foo:prio:#{@test_queue_name}"}}
  end

  test "new queue is empty", context do
    assert PriorityQueue.first(context[:queue]) == {:ok, :empty}
  end

  test "insert value in queue", context do
    assert PriorityQueue.insert(context[:queue], "key_1", 12_345) == :ok
    assert PriorityQueue.first(context[:queue]) ==
           {:ok, %{key: "key_1", prio: 12_345}}
  end

  test "first gets the entry with lowest prio value", context do
    assert PriorityQueue.insert(context[:queue], "key_1", 1) == :ok
    assert PriorityQueue.insert(context[:queue], "key_2", 2) == :ok
    assert PriorityQueue.insert(context[:queue], "key_3", 3) == :ok
    assert PriorityQueue.first(context[:queue]) ==
           {:ok, %{key: "key_1", prio: 1}}
  end

  test "last gets the entry with lowest prio value", context do
    assert PriorityQueue.insert(context[:queue], "key_1", 1) == :ok
    assert PriorityQueue.insert(context[:queue], "key_2", 2) == :ok
    assert PriorityQueue.insert(context[:queue], "key_3", 3) == :ok
    assert PriorityQueue.last(context[:queue]) ==
           {:ok, %{key: "key_3", prio: 3}}
  end

  test "remove deletes entry from queue", context do
    assert PriorityQueue.insert(context[:queue], "key_1", 1) == :ok
    assert PriorityQueue.remove(context[:queue], "key_1") == :ok
    assert PriorityQueue.first(context[:queue]) == {:ok, :empty}
   end

  test "remove unfound entry from queue does not change it", context do
    assert PriorityQueue.insert(context[:queue], "key_1", 1) == :ok
    assert PriorityQueue.remove(context[:queue], "key_2") == {:ok, :not_found}
    assert PriorityQueue.first(context[:queue]) ==
           {:ok, %{key: "key_1", prio: 1}}
  end

  test "count returns proper number of entries", context do
    assert PriorityQueue.insert(context[:queue], "key_1", 1) == :ok
    assert PriorityQueue.insert(context[:queue], "key_1", 1) == :ok
    assert PriorityQueue.insert(context[:queue], "key_2", 2) == :ok
    assert PriorityQueue.insert(context[:queue], "key_3", 3) == :ok
    assert PriorityQueue.insert(context[:queue], "key_4", 4) == :ok
    assert PriorityQueue.count(context[:queue], 0, 0) == {:ok, 0}
    assert PriorityQueue.count(context[:queue], 0, 1) == {:ok, 1}
    assert PriorityQueue.count(context[:queue], 0, 2) == {:ok, 2}
    assert PriorityQueue.count(context[:queue], 0, 3) == {:ok, 3}
    assert PriorityQueue.count(context[:queue], 0, 4) == {:ok, 4}
    assert PriorityQueue.count(context[:queue], 2, 3) == {:ok, 2}
    assert PriorityQueue.count(context[:queue]) == {:ok, 4}
  end
end
