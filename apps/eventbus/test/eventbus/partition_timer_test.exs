defmodule Eventbus.PartitionTimerTest do
  use ExUnit.Case
  alias Eventbus.{PartitionTimer, JobSend, Utils, PriorityQueue, Hash, Redix}

  @topic "pusher"
  @partition 4
  @timer_name PartitionTimer.name(@topic, @partition)
  @prio_name  PriorityQueue.queue(Atom.to_string(@timer_name))
  @hash_name  Hash.hash(Atom.to_string(@timer_name))

  setup do
    System.put_env("PROJECT", "foo")
    {:ok, _} = Redix.command(:redix_pool, ["DEL", @prio_name])
    {:ok, _} = Redix.command(:redix_pool, ["DEL", @hash_name])
    :ok
  end

  test "start_link creates a partition timer process" do
    {:ok, pid} = PartitionTimer.start_link([@timer_name,
                                        [topic: @topic, partition: @partition]])
    assert Process.alive?(pid)
    assert Process.alive?(Process.whereis(@timer_name))
  end

  test "schedule_timer dispatches a job at the right time" do
    {:ok, _} = PartitionTimer.start_link([@timer_name,
                                        [topic: @topic, partition: @partition]])

    job = JobSend.init("message", @topic, @partition, self())
    PartitionTimer.post_delayed_job(@topic, @partition, job, Utils.now() + 50)
    assert_receive("message", 100)
  end

  test "muiltiple schedule_timer dispatches all events at the right time" do
    {:ok, _} = PartitionTimer.start_link([@timer_name,
                                        [topic: @topic, partition: @partition]])

    job = JobSend.init("message1", @topic, @partition, self())
    PartitionTimer.post_delayed_job(@topic, @partition, job, Utils.now() + 200)
    job = JobSend.init("message2", @topic, @partition, self())
    PartitionTimer.post_delayed_job(@topic, @partition, job, Utils.now() + 500)
    refute_receive("message1")
    assert_receive("message1", 300)
    assert_receive("message2", 400)
  end

  test "cancel_timer unschedules timer does not dispatch a job" do
    {:ok, _} = PartitionTimer.start_link([@timer_name,
                                        [topic: @topic, partition: @partition]])

    job = JobSend.init("message", @topic, @partition, self())
    PartitionTimer.post_delayed_job(@topic, @partition, job, Utils.now() + 50)
    PartitionTimer.cancel_delayed_job(@topic, @partition, job.job_id)
    refute_receive("message", 10)
  end

  test "cancel_timer unschedules job but triggers next" do
    {:ok, _} = PartitionTimer.start_link([@timer_name,
                                        [topic: @topic, partition: @partition]])

    job2 = JobSend.init("message2", @topic, @partition, self())
    PartitionTimer.post_delayed_job(@topic, @partition, job2, Utils.now() + 400)
    # PartitionTimer.schedule_timer(@timer_name, job2, Utils.now() + 400)
    job1 = JobSend.init("message1", @topic, @partition, self())
    PartitionTimer.post_delayed_job(@topic, @partition, job1, Utils.now() + 200)
    # PartitionTimer.schedule_timer(@timer_name, job1, Utils.now() + 200)

    PartitionTimer.cancel_delayed_job(@topic, @partition, job1.job_id)

    refute_receive("message1", 200)
    assert_receive("message2", 300)
  end

  test "restarting process preserves the scheduled timers" do
    {:ok, pid} = PartitionTimer.start_link([@timer_name,
                                        [topic: @topic, partition: @partition]])

    job = JobSend.init("message", @topic, @partition, self())
    PartitionTimer.post_delayed_job(@topic, @partition, job, Utils.now() + 200)
    :timer.sleep(50)
    Process.unlink(pid)
    Process.exit(pid, :kill)
    :timer.sleep(50)
    {:ok, _} = PartitionTimer.start_link([@timer_name,
                                        [topic: @topic, partition: @partition]])
    # PartitionTimer.enable_timer(@timer_name)
    assert_receive("message", 500)
  end

  test "reset_timers resets all timers and does not dispatch a job" do
    {:ok, _} = PartitionTimer.start_link([@timer_name,
                                        [topic: @topic, partition: @partition]])

    job1 = JobSend.init("message1", @topic, @partition, self())
    PartitionTimer.post_delayed_job(@topic, @partition, job1, Utils.now() + 200)
    # PartitionTimer.schedule_timer(@timer_name, job1, Utils.now() + 200)
    job2 = JobSend.init("message2", @topic, @partition, self())
    # PartitionTimer.schedule_timer(@timer_name, job2, Utils.now() + 300)
    PartitionTimer.post_delayed_job(@topic, @partition, job2, Utils.now() + 300)

    # PartitionTimer.reset_timers(@timer_name)
    PartitionTimer.reset_timers(@topic, @partition)

    refute_receive("message1", 200)
    refute_receive("message2", 300)
  end

  test "count_timers returns count of timers per topic and partition" do
    {:ok, _} = PartitionTimer.start_link([@timer_name,
                                        [topic: @topic, partition: @partition]])

    job1 = JobSend.init("message1", @topic, @partition, self())
    PartitionTimer.post_delayed_job(@topic, @partition, job1, Utils.now() + 200)
    # PartitionTimer.schedule_timer(@timer_name, job1, Utils.now() + 200)
    job2 = JobSend.init("message2", @topic, @partition, self())
    # PartitionTimer.schedule_timer(@timer_name, job2, Utils.now() + 300)
    PartitionTimer.post_delayed_job(@topic, @partition, job2, Utils.now() + 300)
    :timer.sleep(100)

    assert PartitionTimer.count_timers(@topic, @partition) == 2
  end

end
