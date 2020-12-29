defmodule Eventbus.PartitionConsumer do
  @moduledoc """
  Handles a Partition Consumer
  """
  use GenServer

  alias Eventbus.{PartitionTimer, Job, Utils, Queue, Hash}
  alias Phoenix.PubSub

  require Logger

  defmodule State do
    @moduledoc """
    The state of the partition consumer
    """
    defstruct topic: nil,
              queue: nil,
              map: nil,
              partition: nil,
              timer_pid: nil
  end

  def name_string(topic, partition) do
    "consumer:#{topic}:#{partition}"
  end

  def name(topic, partition) do
    topic
    |> name_string(partition)
    |> String.to_atom()
  end

  def start_link(name, params) do
    GenServer.start_link(__MODULE__, params, name: name)
  end

  def post_job(topic, partition, job) do
    Stats.increment(:counter, :queue_in, topic, partition)

    {:ok, queue} = Queue.init(name_string(topic, partition))
    {:ok, hash} = Hash.init((name_string(topic, partition)))

    :ok = Hash.set(hash, job.job_id, job)
    :ok = Queue.push(queue, job.job_id)

    # notify that job is pending (2 - higher consumer rate than produce)
    PubSub.broadcast Eventbus.PubSub, name_string(topic, partition), {:handle_job, 2}
  end

  def init([topic: topic, partition: partition]) do
    # start timer service for this partition consumer
    timer_name = PartitionTimer.name(topic, partition)
    {:ok, timer_pid} = PartitionTimer.start_link([timer_name,
                                        [topic: topic, partition: partition]])

    {:ok, queue} = Queue.init(name_string(topic, partition))
    {:ok, map} = Hash.init((name_string(topic, partition)))

    PubSub.subscribe Eventbus.PubSub, name_string(topic, partition)

    # process any pending job
    case Queue.count(queue) do
      {:ok, 0} -> :ok
      {:ok, count} -> PubSub.broadcast Eventbus.PubSub, name_string(topic, partition), {:handle_job, count}
      _ -> :ignore
    end

    Stats.increment(:counter, :consumer_start, topic, partition)
    Process.flag(:trap_exit, true)

    {:ok, %State{topic: topic,
                 queue: queue,
                 map: map,
                 partition: partition,
                 timer_pid: timer_pid}}
  end

  def terminate(_reason, state) do
    Stats.increment(:counter, :consumer_stop, state.topic, state.partition)
  end

  def handle_pending_jobs(_state, 0), do: :ok
  def handle_pending_jobs(state, count) do
    case Queue.pop(state.queue) do
      {:ok, :empty} -> :ok
      {:ok, job_id} ->
        get_and_handle_pending_job(state, job_id)
        # process other pending jobs
        handle_pending_jobs(state, count - 1)
      _ -> :ok
    end
  end

  defp get_and_handle_pending_job(state, job_id) do
    case Hash.get(state.map, job_id) do
      {:ok, %{} = job} ->
        handle_pending_job(state, job_id, job)
      error ->
        Logger.error(fn -> "job not found in hash #{inspect error}" end)
        Stats.increment(:counter, :queue_error, "unknown", -1)
    end
  end

  defp handle_pending_job(state, job_id, job) do
    if Map.has_key?(job, :topic) and Map.has_key?(job, :partition) and Map.has_key?(job, :ts) do
      latency = Utils.now() - job.ts
      Stats.report(:latency, :queue, job.topic, job.partition, latency)
      Stats.increment(:counter, :queue_out, job.topic, job.partition)
      Logger.info(fn -> "QUEUE latency: #{latency} topic: #{inspect job.topic} partition: #{inspect job.partition} url: #{inspect job.url}" end)
    end
    try do
      Job.call(job)
      Hash.delete(state.map, job_id)
    rescue
      error ->
        Logger.error(fn -> "job error topic:#{inspect job.topic} partition:#{inspect job.partition} error:#{inspect error}" end)
        Stats.increment(:counter, :queue_error, job.topic, job.partition)
    end
  end

  def handle_info({:handle_job, count}, state) do
    # while event in queue then handle
    handle_pending_jobs(state, count)
    {:noreply, state}
  end

  def handle_info({:EXIT, pid, event}, state) do
    if pid == state.timer_pid and event != :normal do
      timer_name = PartitionTimer.name(state.topic, state.partition)
      {:ok, timer_pid} = PartitionTimer.start_link([timer_name,
                                            [topic: state.topic, partition: state.partition]])
      {:noreply, %State{state | timer_pid: timer_pid}}
    else
      {:noreply, state}
    end
  end

  def topic_hash(key, topic) do
    rem(:erlang.phash2(key), partition_count(topic))
  end

  def partition_count(topic) do
    Application.get_env(:eventbus, :topics)
    |> Enum.reduce(0, fn topic_spec, res ->
      if Keyword.get(topic_spec, :topic) == topic do
        Keyword.get(topic_spec, :partition_count)
      else
        res
      end
    end)
  end

end
