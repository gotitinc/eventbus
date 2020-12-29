defmodule Eventbus.PartitionTimer do
  @moduledoc """
  Manages a timer for the partition
  """
  use GenServer
  alias Eventbus.{PriorityQueue, Hash, Job, Utils}
  alias Phoenix.PubSub
  require Logger

  # Client API

  def name_string(topic, partition) do
    "timer:#{topic}:#{partition}"
  end

  def name(topic, partition) do
    topic
    |> name_string(partition)
    |> String.to_atom()
  end

  def start_link([name, _params], _opts \\ []) do
    GenServer.start_link(__MODULE__,
                        [name],
                        name: name)
  end

  def post_delayed_job(topic, partition, job, timeout) do
    Stats.increment(:counter, :delayed_in, topic, partition)
    timer_name = name_string(topic, partition)

    {:ok, priority_queue} = PriorityQueue.init(timer_name)
    {:ok, map} = Hash.init(timer_name)

    Hash.set(map, job.job_id, job)
    PriorityQueue.insert(priority_queue, job.job_id, timeout)
    PubSub.broadcast(Eventbus.PubSub, timer_name, :update_timer)
  end

  def cancel_delayed_job(topic, partition, job_id) do
    timer_name = name_string(topic, partition)
    {:ok, map} = Hash.init(timer_name)
    Hash.delete(map, job_id)

    # {:ok, priority_queue} = PriorityQueue.init(timer_name)
  end

  def reset_timers(topic, partition) do
    timer_name = name_string(topic, partition)

    with {:ok, priority_queue} <- PriorityQueue.init(timer_name),
         {:ok, map} <- Hash.init(timer_name) do
      PriorityQueue.reset(priority_queue)
      Hash.reset(map)
    end
    PubSub.broadcast(Eventbus.PubSub, timer_name, :update_timer)
  end

  def count_timers(topic, partition) do
    timer_name = name_string(topic, partition)
    with {:ok, priority_queue} <- PriorityQueue.init(timer_name),
         {:ok, count} <- PriorityQueue.count(priority_queue) do
      count
    else
      _ -> 0
    end
  end

  # Callbacks

  @impl true
  def init([name]) do
    # get the pending tasks from priority queue and schedule timer
    timer_name = Atom.to_string(name)
    {:ok, priority_queue} = PriorityQueue.init(timer_name)
    {:ok, map} = Hash.init(timer_name)

    PubSub.subscribe(Eventbus.PubSub, timer_name)

    state = schedule_next(%{name: name,
                            priority_queue: priority_queue,
                            map: map,
                            timer_ref: nil,
                            job_id: nil,
                            next_timeout: nil})
    {:ok, state}
  end

  @impl true
  def handle_cast({:schedule_timer, job, timeout}, state) do
    # insert job
    Hash.set(state.map, job.job_id, job)
    PriorityQueue.insert(state.priority_queue, job.job_id, timeout)
    # if new job is earlier than current timer then reschedule it

    if is_nil(state.next_timeout) or timeout < state.next_timeout do
      cancel_timer(state.timer_ref)
      timer_ref = set_timer(job.job_id, timeout)
      {:noreply, %{state | timer_ref: timer_ref, job_id: job.job_id, next_timeout: timeout}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:dismiss_timer, job_id}, state) do
    cancel_timer(state.timer_ref)
    Hash.delete(state.map, job_id)
    PriorityQueue.remove(state.priority_queue, job_id)
    {:noreply, schedule_next(%{state | timer_ref: nil, job_id: nil, next_timeout: nil})}
  end

  @impl true
  def handle_cast(:reset_timers, state) do
    if not is_nil(state.next_timeout) do
      cancel_timer(state.timer_ref)
    end

    PriorityQueue.reset(state.priority_queue)
    Hash.reset(state.map)
    {:noreply, %{state | timer_ref: nil, job_id: nil, next_timeout: nil}}
  end

  @impl true
  def handle_info(:update_timer, state) do
    state = case PriorityQueue.first(state.priority_queue) do
      {:ok, :empty} ->
        cancel_timer(state.timer_ref)
        %{state | timer_ref: nil, next_timeout: nil}
      {:ok, %{key: job_id, prio: timeout}} ->
        if job_id != state.job_id do
          cancel_timer(state.timer_ref)
          timer_ref = set_timer(job_id, timeout)
          %{state | timer_ref: timer_ref, job_id: job_id, next_timeout: timeout}
        else
          state
        end
      error ->
        Logger.error(fn -> "PriorityQueue.first(#{state.name}) failed with error #{inspect error} " end)
        state
    end
    {:noreply, state}
  end

  @impl true
  def handle_info({:timeout, job_id}, state) do
    case Hash.get(state.map, job_id) do
      {:ok, %{} = job} ->
        Hash.delete(state.map, job_id)
        PriorityQueue.remove(state.priority_queue, job_id)
        try do
          if Map.has_key?(job, :topic) and Map.has_key?(job, :partition) do
            Stats.increment(:counter, :delayed_out, job.topic, job.partition)
          end
          latency = Utils.now() - job.ts
          Logger.info(fn -> "DELAY latency: #{latency} topic: #{inspect job.topic} partition: #{inspect job.partition} url: #{inspect job.url}" end)

          Job.call(job)
        rescue
          RuntimeError ->
            Logger.error(fn -> "RuntimeError #{inspect job}" end)
            Stats.increment(:counter, :delayed_error, "unknown", -1)
          Protocol.UndefinedError ->
            Logger.error(fn -> "Protocol.UndefinedError  #{inspect job}" end)
            Stats.increment(:counter, :delayed_error, "unknown", -1)
          UndefinedFunctionError ->
            Logger.error(fn -> "UndefinedFunctionError #{inspect job}" end)
            Stats.increment(:counter, :delayed_error, "unknown", -1)
        end
      error ->
        # probably a canceled job, just remove the job_id from prio queue
        Logger.error(fn -> "UnknownError job_id: #{inspect job_id} error: #{inspect error}" end)
        PriorityQueue.remove(state.priority_queue, job_id)
        Stats.increment(:counter, :delayed_canceled, "unknown", -1)
    end

    {:noreply, schedule_next(state)}
  end

  defp schedule_next(state) do
    case PriorityQueue.first(state.priority_queue) do
      {:ok, :empty} ->
        %{state | timer_ref: nil, next_timeout: nil}
      {:ok, %{key: job_id, prio: timeout}} ->
        timer_ref = set_timer(job_id, timeout)
        %{state | timer_ref: timer_ref, job_id: job_id, next_timeout: timeout}
      error ->
        Logger.error(fn -> "PriorityQueue.first(#{state.name}) failed with error #{inspect error} " end)
        state
    end
  end

  defp set_timer(job_id, timeout) do
    delay = Utils.delay(timeout)
    Process.send_after(self(), {:timeout, job_id}, delay)
  end

  defp cancel_timer(nil) do
   :ok
  end
  defp cancel_timer(timer_ref) do
    Process.cancel_timer(timer_ref, [async: true, info: false])
  end

end
