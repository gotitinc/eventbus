defmodule EventbusTest do
  use ExUnit.Case, async: false

  alias Eventbus.{PartitionManager, StatsManager, PartitionConsumer,
                  ClusterManager, TopicSupervisor, Tracker, JobHttpMock}

  def wait_if(alive, pid) do
    if (alive == :alive) == Process.alive?(pid) do
      :timer.sleep(5)
      wait_if(alive, pid)
    end
  end

  def wait_until_registered(name) do
    if Process.whereis(name) == nil do
      :timer.sleep(100)
      wait_until_registered(name)
    end
  end

  setup do
    {:ok, topic_supervisor} = TopicSupervisor.start_link(TopicSupervisor.name("router"), [topic: "router", partition_count: 1])
    {:ok, topic_supervisor2} = TopicSupervisor.start_link(TopicSupervisor.name("_other"), [topic: "_other", partition_count: 1])
    [ok: cluster_manager, ok: tracker, ok: stats_manager, ok: partition_manager] = Eventbus.Application.start_managers()

    partition_consumer = PartitionConsumer.name("router", 0)
    wait_until_registered(partition_consumer)

    partition_consumer2 = PartitionConsumer.name("_other", 0)
    wait_until_registered(partition_consumer2)

    Eventbus.reset_counters()

    on_exit fn ->
      wait_if(:alive, topic_supervisor)
      wait_if(:alive, topic_supervisor2)
      wait_if(:alive, partition_manager)
      wait_if(:alive, stats_manager)
      wait_if(:alive, tracker)
      wait_if(:alive, cluster_manager)
    end
    :ok
  end

  test "managers start" do
    pid = Process.whereis(PartitionManager)
    assert pid != nil
    assert Process.alive?(pid)

    pid = Process.whereis(StatsManager)
    assert pid != nil
    assert Process.alive?(pid)

    pid = Process.whereis(Tracker)
    assert pid != nil
    assert Process.alive?(pid)

    pid = Process.whereis(ClusterManager)
    assert pid != nil
    assert Process.alive?(pid)
  end

  test "get counters" do
    assert Eventbus.get_counter(:queue, "router") == 0
  end

  test "produce results in http request" do
    {:ok, :sent} = Eventbus.produce("router",
                                    "key",
                                    url: "http://httpbin.org/post",
                                    payload: {[], self()},
                                    job_module: JobHttpMock)

    assert Eventbus.get_latency(:queue, "router") == %{nonode@nohost: Stats.empty(:latency)}
    assert_receive({[], "http://httpbin.org/post", "router", 0}, 200)
    assert Eventbus.get_counter(:queue, "router") == 0
    assert Eventbus.get_latency(:queue, "router") != %{nonode@nohost: Stats.empty(:latency)}
    StatsManager.reset_counter(:queue, "router")
    assert Eventbus.get_counter(:queue, "router") == 0
    StatsManager.reset_latency(:queue, "router")
    assert Eventbus.get_latency(:queue, "router") == %{nonode@nohost: Stats.empty(:latency)}
  end

  test "produce_delayed results in http request" do
    {:ok, :sent} = Eventbus.produce_delayed("router",
                                            "key",
                                            url: "http://httpbin.org/post",
                                            payload: {[], self()},
                                            delay: 1000,
                                            job_module: JobHttpMock)

    refute_receive({[], "http://httpbin.org/post", "router", 0})
    assert Eventbus.get_counter(:delayed_in, "router") == %{nonode@nohost: 1}
    assert Eventbus.get_counter(:delayed_out, "router") == %{nonode@nohost: 0}
    assert_receive({[], "http://httpbin.org/post", "router", 0}, 1200)
    assert Eventbus.get_counter(:delayed_out, "router") == %{nonode@nohost: 1}
  end

  test "reset_events clears queued events and stats" do
    {:ok, :sent} = Eventbus.produce_delayed("router",
                                            "key",
                                            url: "http://httpbin.org/post",
                                            payload: {[], self()},
                                            delay: 500,
                                            job_module: JobHttpMock)

    refute_receive({[], "http://httpbin.org/post", "router", 0})
    assert Eventbus.get_counter(:delayed_in, "router") == %{nonode@nohost: 1}
    assert Eventbus.reset_events()
    refute_receive({[], "http://httpbin.org/post", "router", 0}, 600)
    assert Eventbus.get_counter(:delayed_in, "router") == %{nonode@nohost: 0}
  end

  test "partition_counter returns configured values" do
    Application.get_env(:eventbus, :topics, [])
    |> Enum.each(fn [topic: topic, partition_count: partition_count] ->
      assert Eventbus.partition_count(topic) == partition_count
    end)
  end

  test "produce with unknown topic results in http request" do
    {:ok, :sent} = Eventbus.produce("unknown",
                                    "key",
                                    url: "http://httpbin.org/post",
                                    payload: {[], self()},
                                    job_module: JobHttpMock)

    assert Eventbus.get_latency(:queue, "_other") == %{nonode@nohost: Stats.empty(:latency)}
    assert_receive({[], "http://httpbin.org/post", "_other", 0}, 200)
    assert Eventbus.get_counter(:queue, "_other") == 0
    assert Eventbus.get_latency(:queue, "_other") != %{nonode@nohost: Stats.empty(:latency)}
    StatsManager.reset_counter(:queue, "_other")
    assert Eventbus.get_counter(:queue, "_other") == 0
    StatsManager.reset_latency(:queue, "_other")
    assert Eventbus.get_latency(:queue, "_other") == %{nonode@nohost: Stats.empty(:latency)}
  end

  test "produce_delayed with unknown topic results in http request" do
    {:ok, :sent} = Eventbus.produce_delayed("unknown",
                                            "key",
                                            url: "http://httpbin.org/post",
                                            payload: {[], self()},
                                            delay: 1000,
                                            job_module: JobHttpMock)

    refute_receive({[], "http://httpbin.org/post", "_other", 0})
    assert Eventbus.get_counter(:delayed_in, "_other") == %{nonode@nohost: 1}
    assert Eventbus.get_counter(:delayed_out, "_other") == %{nonode@nohost: 0}
    assert_receive({[], "http://httpbin.org/post", "_other", 0}, 1200)
    assert Eventbus.get_counter(:delayed_out, "_other") == %{nonode@nohost: 1}
  end
end
