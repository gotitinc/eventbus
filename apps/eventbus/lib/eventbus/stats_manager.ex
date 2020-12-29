defmodule Eventbus.StatsManager do
  @moduledoc """
  Manages multi-node services for counters services
  """
  use GenServer
  alias Eventbus.{Tracker, PartitionConsumer, Queue, PriorityQueue}

  @topic "stats"

  defmodule State do
    @moduledoc """
    The state of the stats manager
    """
    defstruct assignments: [],
              tracker: nil
  end

  def start_link(name, params) do
    GenServer.start_link(__MODULE__, params, name: name)
  end

  def enable_service() do
    case Process.whereis(__MODULE__) do
      nil -> :ignore
      pid -> GenServer.cast(pid, :enable)
    end
  end

  def handle_event(diff) do
    case Process.whereis(__MODULE__) do
      nil -> :ignore
      pid -> GenServer.cast(pid, {:event, diff})
    end
  end

  def call_stats_remote(pid, function, args) do
    GenServer.call(pid, {:call_stats, function, args})
  end

  def get_assignments() do
    GenServer.call(__MODULE__, :get_assignments)
  end

  def call_stats(function, args) do
    assignments = get_assignments()
    tasks = Enum.reduce(assignments, [], fn {node, spec}, acc ->
      [Task.async(fn ->
        %{node => call_stats_remote(Map.get(spec, :pid), function, args)}
      end) | acc]
    end)
    Enum.reduce(tasks, %{}, fn task, acc ->
      Map.merge(acc, Task.await(task))
    end)
  end

  def reset_all_counters() do
    call_stats(:reset_all, [])
  end

  def reset_counter(counter, topic) do
    get_partition_count_for_topic topic, fn partition_count ->
      call_stats(:reset_many, [:counter, counter, topic, 0..(partition_count - 1)])
    end
  end

  def get_counter(counter, topic) do
    get_partition_count_for_topic topic, fn partition_count ->
      call_stats(:get_many, [:counter, counter, topic, 0..(partition_count - 1)])
    end
  end

  def reset_latency(counter, topic) do
    get_partition_count_for_topic topic, fn partition_count ->
      call_stats(:reset_many, [:latency, counter, topic, 0..(partition_count - 1)])
    end
  end

  def get_latency(counter, topic) do
    get_partition_count_for_topic topic, fn partition_count ->
      call_stats(:get_many, [:latency, counter, topic, 0..(partition_count - 1)])
    end
  end

  def get_queue(topic) do
    GenServer.call(__MODULE__, {:get_queue, topic})
  end

  def get_timer(topic) do
    GenServer.call(__MODULE__, {:get_timer, topic})
  end

  # callbacks

  def init(params) do
    tracker = Keyword.get(params, :tracker, Tracker)
    GenServer.cast(self(), :enable)
    {:ok, %State{tracker: tracker}}
  end

  def handle_cast(:enable, state) do
    if state.tracker.alive?() do
      state.tracker.track(self(), @topic, node(), %{node: node(), pid: self(), state: :online})
    end
    {:noreply, state}
  end

  def handle_cast({:event, %{@topic => {_added, _removed}}}, state) do
    assignments = state.tracker.list(@topic)
    {:noreply, %State{state | assignments: assignments}}
  end
  def handle_cast({:event, _}, state), do: {:noreply, state}

  def handle_call({:call_stats, function, args}, _from, state) do
    res = Kernel.apply(Stats, function, args)
    {:reply, res, state}
  end

  def handle_call(:get_assignments, _from, state) do
    {:reply, state.assignments, state}
  end

  def handle_call({:get_queue, topic}, _from, state) do
    res = get_partition_count_for_topic topic, fn partition_count ->
      0..(partition_count - 1)
      |> Enum.map(fn partition ->
        {:ok, queue} = Queue.init(PartitionConsumer.name_string(topic, partition))
        {:ok, val} = Queue.count(queue)
        :timer.sleep(1)
        val
      end)
      |> Enum.sum
    end
    {:reply, res, state}
  end
  def handle_call({:get_timer, topic}, _from, state) do
    res = get_partition_count_for_topic topic, fn partition_count ->
      0..(partition_count - 1)
      |> Enum.map(fn partition ->
        {:ok, queue} = PriorityQueue.init(PartitionConsumer.name_string(topic, partition))
        {:ok, val} = PriorityQueue.count(queue)
        :timer.sleep(1)
        val
      end)
      |> Enum.sum
    end
    {:reply, res, state}
  end

  def get_partition_count_for_topic(topic, fun) do
    Application.get_env(:eventbus, :topics)
    |> Enum.filter(fn [topic: t, partition_count: _] -> t == topic end)
    |> case do
      [[topic: ^topic, partition_count: partition_count]] ->
        fun.(partition_count)
      _ ->
        %{error: "invalid topic"}
    end
  end
end
