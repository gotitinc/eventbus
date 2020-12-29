defmodule StatsTest do
  use ExUnit.Case

  setup do
    # :ets.new(:stats_table, [:set, :named_table, read_concurrency: true])
    Stats.reset_all()
    :ok
  end

  test "create counter initializes entry with 0" do
    name = :produce_in
    topic = "router"
    partition = 0
    assert Stats.reset(:counter, name, topic, partition)
    assert Stats.get(:counter, name, topic, partition) == 0
  end

  test "create latency counter initializes entry" do
    name = :queue
    topic = "router"
    partition = 0
    assert Stats.reset(:latency, name, topic, partition)
    assert Stats.get(:latency, name, topic, partition) == %{
      min: -1,
      max: -1,
      _smaller_10: 0,
      _10_100: 0,
      _100_1k: 0,
      _1k_10k: 0,
      _larger_10k: 0
    }
  end

  test "incr adds value to entry" do
    name = :produce_in
    topic = "router"
    partition = 0
    value = 7
    assert Stats.create(:counter, name, topic, partition)
    assert Stats.increment(:counter, name, topic, partition, value)
    assert Stats.get(:counter, name, topic, partition) == value
  end

  test "incr queue_in adds value to queue" do
    topic = "router"
    partition = 0
    value = 7
    assert Stats.increment(:counter, :queue_in, topic, partition, value)
    assert Stats.get(:counter, :queue, topic, partition) == value
  end

  test "incr queue_out substact value to queue" do
    topic = "router"
    partition = 0
    value = 7
    assert Stats.increment(:counter, :queue_out, topic, partition, value)
    assert Stats.get(:counter, :queue, topic, partition) == -value
  end

  test "incr delayed_in adds value to delayed" do
    topic = "router"
    partition = 0
    value = 7
    assert Stats.increment(:counter, :delayed_in, topic, partition, value)
    assert Stats.get(:counter, :delayed, topic, partition) == value
  end

  test "incr delayed_out substract value to delayed" do
    topic = "router"
    partition = 0
    value = 7
    assert Stats.increment(:counter, :delayed_out, topic, partition, value)
    assert Stats.get(:counter, :delayed, topic, partition) == -value
  end

  test "incr handles string partition" do
    name = :produce_in
    topic = "router"
    partition = "0"
    value = 7
    assert Stats.create(:counter, name, topic, partition)
    assert Stats.increment(:counter, name, topic, partition, value)
    assert Stats.get(:counter, name, topic, partition) == value
  end

  test "non string or integer partition defaults to 0" do
    name = :produce_in
    topic = "router"
    partition = :foo
    value = 7
    assert Stats.create(:counter, name, topic, partition)
    assert Stats.increment(:counter, name, topic, partition, value)
    assert Stats.get(:counter, name, topic, 0) == value
  end

  test "reset sets value of entry back to 0" do
    name = :produce_in
    topic = "router"
    partition = 0
    assert Stats.create(:counter, name, topic, partition)
    assert Stats.increment(:counter, name, topic, partition, 7)
    assert Stats.reset(:counter, name, topic, partition)
    assert Stats.get(:counter, name, topic, partition) == 0
  end

  test "get uncreated counter returns 0" do
    name = :produce_in
    topic = "router"
    partition = 3
    assert Stats.get(:counter, name, topic, partition) == 0
  end

  test "incrementing uncreated counter initializes it 0" do
    name = :produce_in
    topic = "router"
    partition = 4
    assert Stats.increment(:counter, name, topic, partition, 7)
    assert Stats.get(:counter, name, topic, partition) == 7
  end

  test "reporting a latency initializes and updates fields" do
    name = :queue_in
    topic = "router"
    partition = 4
    assert Stats.report(:latency, name, topic, partition, 1)
    assert Stats.get(:latency, name, topic, partition) ==
      %{_100_1k: 0, _10_100: 0, _1k_10k: 0, _larger_10k: 0, max: 1, min: 1, _smaller_10: 1}
    assert Stats.report(:latency, name, topic, partition, 12)
    assert Stats.get(:latency, name, topic, partition) ==
      %{_100_1k: 0, _10_100: 1, _1k_10k: 0, _larger_10k: 0, max: 12, min: 1, _smaller_10: 1}
    assert Stats.report(:latency, name, topic, partition, 101)
    assert Stats.get(:latency, name, topic, partition) ==
      %{_100_1k: 1, _10_100: 1, _1k_10k: 0, _larger_10k: 0, max: 101, min: 1, _smaller_10: 1}
    assert Stats.report(:latency, name, topic, partition, 1002)
    assert Stats.get(:latency, name, topic, partition) ==
      %{_100_1k: 1, _10_100: 1, _1k_10k: 1, _larger_10k: 0, max: 1002, min: 1, _smaller_10: 1}
    assert Stats.report(:latency, name, topic, partition, 15_002)
    assert Stats.get(:latency, name, topic, partition) ==
      %{_100_1k: 1, _10_100: 1, _1k_10k: 1, _larger_10k: 1, max: 15_002, min: 1, _smaller_10: 1}
    assert Stats.report(:latency, name, topic, partition, 150)
    assert Stats.get(:latency, name, topic, partition) ==
      %{_100_1k: 2, _10_100: 1, _1k_10k: 1, _larger_10k: 1, max: 15_002, min: 1, _smaller_10: 1}
  end

  test "reseting a latency clears all values" do
    name = :kafka
    topic = "router"
    partition = 5
    assert Stats.report(:latency, name, topic, partition, 101)
    assert Stats.get(:latency, name, topic, partition) ==
      %{_100_1k: 1, _10_100: 0, _1k_10k: 0, _larger_10k: 0, max: 101, min: 101, _smaller_10: 0}
    assert Stats.reset(:latency, name, topic, partition)
    assert Stats.get(:latency, name, topic, partition) ==
      %{_100_1k: 0, _10_100: 0, _1k_10k: 0, _larger_10k: 0, max: -1, min: -1, _smaller_10: 0}
  end

  test "reset_many and get_many counter works on multiple partitions" do
    topic = "router"
    assert Stats.increment(:counter, :queue_in, topic, 0, 7)
    assert Stats.increment(:counter, :queue_in, topic, 1, 8)
    assert Stats.get_many(:counter, :queue_in, topic, [0, 1]) == 15
    assert Stats.reset_many(:counter, :queue_in, topic, [0, 1])
    assert Stats.get_many(:counter, :queue_in, topic, [0, 1]) == 0
  end

  test "reset_many and get_many latency works on multiple partitions" do
    topic = "router"
    name = "queue"
    assert Stats.report(:latency, name, topic, 0, 101)
    assert Stats.report(:latency, name, topic, 1, 102)
    assert Stats.report(:latency, name, topic, 2, 101)
    assert Stats.get_many(:latency, name, topic, [0, 1, 2]) ==
      %{_100_1k: 3, _10_100: 0, _1k_10k: 0, _larger_10k: 0, max: 102, min: 101, _smaller_10: 0}
    assert Stats.reset_many(:latency, :queue_in, topic, [0, 1, 2])
    assert Stats.get_many(:latency, :queue_in, topic, [0, 1, 2]) ==
      %{_100_1k: 0, _10_100: 0, _1k_10k: 0, _larger_10k: 0, max: -1, min: -1, _smaller_10: 0}
  end

end
