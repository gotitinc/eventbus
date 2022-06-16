defmodule Eventbus.TestPartitionManager do
  use ExUnit.Case

  alias Eventbus.{PartitionManager, ConfigStore}

  @topic "eventbus"

  defmodule TrackerMock do
    def list(_topic) do
      [{node(), :dummy}]
    end

    def alive?(), do: true

    def track(tracked_pid, topic, node, meta) do
      send(:test, {:track, tracked_pid, topic, node, meta})
    end

    def untrack(tracked_pid, topic, node) do
      send(:test, {:untrack, tracked_pid, topic, node})
    end
  end

  defmodule TopicSupervisorMock do
    def start_consumer(topic, partition) do
      send(:test, {:start_consumer, topic, partition})
    end

    def terminate_consumer(topic, partition) do
      send(:test, {:terminate_consumer, topic, partition})
    end
  end

  setup do
    ConfigStore.init()
    Application.get_env(:eventbus, :topics, [])
    |> ConfigStore.put_topics_spec()
    {:ok, %{}}
  end

  test "partition_manager is initialized" do
    {:ok, pid} = PartitionManager.start_link(Eventbus.PartitionManager, [])
    assert Process.alive?(pid)
    state = :sys.get_state(pid)
    assert state.hash_ring == HashRing.new()
    assert state.tracker == Eventbus.Tracker
    assert state.topic_supervisor == Eventbus.TopicSupervisor
    assert state.start_delay == Application.get_env(:eventbus, :start_delay)
    assert state.topics_spec == ConfigStore.get_topics_spec()
  end

  test "enable registers with tracker" do
    Process.register(self(), :test)
    {:ok, _} = Eventbus.Tracker.start_link(Eventbus.Tracker, [])
    {:ok, pid} = PartitionManager.start_link(Eventbus.PartitionManager, [tracker: TrackerMock])
    # PartitionManager.enable_service()

    expected_message = {:track, pid, @topic, node(), %{node: node(), pid: pid, state: :online}}
    assert_receive(^expected_message, 100)
  end

  test "disable unregisters with tracker" do
    Process.register(self(), :test)
    {:ok, pid} = PartitionManager.start_link(Eventbus.PartitionManager, [tracker: TrackerMock])
    PartitionManager.disable_service()

    expected_message = {:untrack, pid, @topic, node()}
    assert_receive(^expected_message, 100)
  end

  test "update_hash_ring adds entries" do
    expected_hash_ring = HashRing.new()
    |> HashRing.add_node(:node1)
    |> HashRing.add_node(:node2)
    assert PartitionManager.update_hash_ring(HashRing.new(), [{:node1, :other}, {:node2, :other}], []) == expected_hash_ring
  end

  test "update_hash_ring removes entries" do
    initial_hash_ring = HashRing.new()
    |> HashRing.add_node(:node1)
    |> HashRing.add_node(:node2)
    assert PartitionManager.update_hash_ring(initial_hash_ring, [], [{:node1, :other}, {:node2, :other}]) == HashRing.new()
  end

  test "handle_event properly handles event" do
    Process.register(self(), :test)
    {:ok, pid} = PartitionManager.start_link(Eventbus.PartitionManager, [tracker: TrackerMock])
    PartitionManager.handle_event(%{@topic => {[{node(), :dummy}], []}})
    :timer.sleep(100)
    state = :sys.get_state(pid)
    expected_hashring = HashRing.new() |> HashRing.add_node(node())
    assert state.hash_ring == expected_hashring

    expected_assignments = Enum.reduce(state.topics_spec, %{}, fn [topic: topic, partition_count: partition_count], map1 ->
      Enum.reduce(0..(partition_count - 1), map1, fn partition, map2 ->
        this_node = node()
        Map.put(map2, this_node, [{topic, partition} | Map.get(map2, this_node, [])])
      end)
    end)

    assert state.assignments == expected_assignments
  end

  test "bootstrap starts all assigments" do
    Process.register(self(), :test)
    {:ok, pid} = PartitionManager.start_link(Eventbus.PartitionManager,
        [tracker: TrackerMock, topic_supervisor: TopicSupervisorMock, start_delay: 100])

    :timer.sleep(150)
    PartitionManager.handle_event(%{@topic => {[{node(), :dummy}], []}})
    :timer.sleep(50)
    state = :sys.get_state(pid)
    assert state.status == :started

    ConfigStore.get_topics_spec()
    |> Enum.reverse()
    |> Enum.each(fn [topic: topic, partition_count: partition_count] ->
      Enum.each(partition_count-1..0, fn partition ->
        assert_receive({:start_consumer, ^topic, ^partition}, 100)
      end)
    end)
  end

end
