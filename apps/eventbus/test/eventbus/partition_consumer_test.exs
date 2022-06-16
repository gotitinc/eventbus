defmodule Eventbus.PartitionConsumerTest do
  use ExUnit.Case

  alias Eventbus.{PartitionConsumer, JobSend, Queue, Hash, ConfigStore}

  setup do
    topic = "topic"
    partition = 7

    {:ok, queue} = Queue.init(PartitionConsumer.name_string(topic, partition))
    {:ok, hash} = Hash.init((PartitionConsumer.name_string(topic, partition)))
    :ok = Hash.reset(hash)
    :ok = Queue.reset(queue)

    ConfigStore.init()
    Application.get_env(:eventbus, :topics, [])
    |> ConfigStore.put_topics_spec()

    {:ok, %{topic: topic, partition: partition, queue: queue, hash: hash}}
  end


  test "init starts the timer process and resets state",
          %{topic: topic, partition: partition} do
    {:ok, pid} = PartitionConsumer.start_link(
                          PartitionConsumer.name(topic, partition),
                          [topic: topic, partition: partition])

    state = :sys.get_state(pid)
    assert state.topic == topic
    assert state.partition == partition
    assert Process.alive?(state.timer_pid)
  end

  test "post job inserts entry in queue and hash",
            %{topic: topic, partition: partition, queue: queue, hash: hash} do
    job = JobSend.init("message", topic, partition, self())
    PartitionConsumer.post_job(topic, partition, job)

    assert Queue.pop(queue) == {:ok, job.job_id}
    assert Hash.get(hash, job.job_id) == {:ok, job}
  end

  test "partition_consumer consumes any pending job upon creation",
          %{topic: topic, partition: partition} do
    job = JobSend.init("message", topic, partition, self())
    PartitionConsumer.post_job(topic, partition, job)

    {:ok, _spid} = PartitionConsumer.start_link(
                          PartitionConsumer.name(topic, partition),
                          [topic: topic, partition: partition])

    assert_receive("message", 100)
  end

  test "partition_consumer consumes posted job",
          %{topic: topic, partition: partition} do
    {:ok, _spid} = PartitionConsumer.start_link(
                          PartitionConsumer.name(topic, partition),
                          [topic: topic, partition: partition])

    job = JobSend.init("message", topic, partition, self())
    PartitionConsumer.post_job(topic, partition, job)

    assert_receive("message", 100)
  end

  test "partition_consumer consumes all posted job in order",
          %{topic: topic, partition: partition} do
    job = JobSend.init("message1", topic, partition, self())
    PartitionConsumer.post_job(topic, partition, job)
    job = JobSend.init("message2", topic, partition, self())
    PartitionConsumer.post_job(topic, partition, job)

    {:ok, _spid} = PartitionConsumer.start_link(
                          PartitionConsumer.name(topic, partition),
                          [topic: topic, partition: partition])

    assert_receive("message1", 100)
    assert_receive("message2", 100)
  end

  test "partition_count returns the correct number of partitions" do
    ConfigStore.get_topics_spec()
    |> Enum.each(fn [topic: topic, partition_count: partition_count] ->
      assert PartitionConsumer.partition_count(topic) == partition_count
    end)
  end

end
