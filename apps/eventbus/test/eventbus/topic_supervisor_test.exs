defmodule Eventbus.TopicSupervisorTest do
  use ExUnit.Case, async: false

  alias Eventbus.{TopicSupervisor, PartitionConsumer}

  def wait_if_alive(pid) do
    if Process.alive?(pid) do
      :timer.sleep(5)
      wait_if_alive(pid)
    end
  end

  setup do
    {:ok, topic_supervisor} = TopicSupervisor.start_link(TopicSupervisor.name("router"), [topic: "router", partition_count: 1])
    on_exit fn ->
      wait_if_alive(topic_supervisor)
    end
    :ok
  end

  test "start consumers" do
    {:ok, pid} = TopicSupervisor.start_consumer("router", 0)
    assert Process.alive?(pid)
    name = PartitionConsumer.name("router", 0)
    assert Process.whereis(name) == pid
  end

  test "stop consumers" do
    {:ok, pid} = TopicSupervisor.start_consumer("router", 0)
    :ok = TopicSupervisor.terminate_consumer("router", 0)
    refute Process.alive?(pid)
    name = PartitionConsumer.name("router", 0)
    refute Process.whereis(name)
  end

end
