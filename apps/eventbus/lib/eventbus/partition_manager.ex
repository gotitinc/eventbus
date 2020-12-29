defmodule Eventbus.PartitionManager do
  @moduledoc """
  Manages partition allocation for this node
  """

  use GenServer
  alias Eventbus.{TopicSupervisor, Tracker}
  require Logger

  @topic "eventbus"

  defmodule State do
    @moduledoc """
    The state of the partition consumer
    """
    defstruct hash_ring: nil,
              topics_spec: [],
              assignments: %{},
              tracker: nil,
              topic_supervisor: nil,
              start_delay: 0,
              status: :init
  end

  def start_link(name, params) do
    GenServer.start_link(__MODULE__, params, name: name)
  end

  def handle_event(diff) do
    case Process.whereis(__MODULE__) do
      nil -> :ignore
      pid -> GenServer.cast(pid, {:event, diff})
    end
  end

  def enable_service() do
    case Process.whereis(__MODULE__) do
      nil -> :ignore
      pid -> GenServer.cast(pid, :enable)
    end
  end

  def disable_service() do
    case Process.whereis(__MODULE__) do
      nil -> :ignore
      pid -> GenServer.cast(pid, :disable)
    end
  end

  def init(params) do
    start_delay = Application.get_env(:eventbus, :start_delay)
    start_delay = Keyword.get(params, :start_delay, start_delay)

    GenServer.cast(self(), :enable)

    {:ok, %State{
      hash_ring: HashRing.new(),
      tracker: Keyword.get(params, :tracker, Tracker),
      topic_supervisor: Keyword.get(params, :topic_supervisor, TopicSupervisor),
      start_delay: start_delay,
      topics_spec: Application.get_env(:eventbus, :topics, [])
    }}
  end

  def handle_cast(:enable, %{status: :init} = state) do
    status = if state.tracker.alive?() do
      state.tracker.track(self(), @topic, node(), %{node: node(), pid: self(), state: :online})
      # if joined cluster then wait for tracker to sync before assigning partitions
      if Node.list == [] do
        send(__MODULE__, :start)
      else
        Process.send_after(__MODULE__, :start, state.start_delay)
      end
      :enabled
    else
      enable_service()
      :timer.sleep(500)
      :init
    end
    {:noreply, %State{state | status: status}}
  end
  def handle_cast(:enable, %{status: :disabled} = state) do
    state.tracker.track(self(), @topic, node(), %{node: node(), pid: self(), state: :online})
    {:noreply, state}
  end
  def handle_cast(:enable, state), do: {:noreply, state}

  def handle_cast(:disable, state) do
    state.tracker.untrack(self(), @topic, node())
    {:noreply, %State{state | status: :disabled}}
  end

  def handle_cast({:event, %{@topic => {_added, _removed}}}, state) do
    hash_ring = @topic
    |> state.tracker.list()
    |> Enum.reduce(HashRing.new(), fn {node, _}, hash_ring ->
        HashRing.add_node(hash_ring, node)
    end)

    state = %State{state | hash_ring: hash_ring}
    |> find_new_assignments()

    {:noreply, state}
  end
  def handle_cast({:event, _}, state), do: {:noreply, state}

  def handle_info(:start, %{status: :enabled} = state) do
    node_asssignemnts = Map.get(state.assignments, node(), [])
    Enum.each(node_asssignemnts, fn {topic, partition} ->
      TopicSupervisor.start_consumer(topic, partition)
    end)
    Logger.info("PartitionManager started: enabled #{Enum.count(node_asssignemnts)} partitions")
    {:noreply, %State{state | status: :started}}
  end
  def handle_info(:start, state), do: {:noreply, state}

  def handle_info(arg, state) do
    Logger.error("unexpected info received #{inspect arg}")
    {:noreply, state}
  end

  def update_hash_ring(hash_ring, added, removed) do
    hash_ring = Enum.reduce(added, hash_ring, fn {node, _}, hash_ring ->
      HashRing.add_node(hash_ring, node)
    end)
    hash_ring = Enum.reduce(removed, hash_ring, fn {node, _}, hash_ring ->
      HashRing.remove_node(hash_ring, node)
    end)
    hash_ring
  end

  def find_new_assignments(state) do
    assignments = Enum.reduce(state.topics_spec, %{}, fn [topic: topic, partition_count: partition_count], map1 ->
      Enum.reduce(0..(partition_count - 1), map1, fn partition, map2 ->
        node = HashRing.key_to_node(state.hash_ring, {topic, partition})
        Map.put(map2, node, [{topic, partition} | Map.get(map2, node, [])])
      end)
    end)

    node_old_asssignemnts = Map.get(state.assignments, node(), [])
    node_new_assigments = Map.get(assignments, node(), [])


    if state.status == :started do
      added = node_new_assigments -- node_old_asssignemnts
      removed = node_old_asssignemnts -- node_new_assigments
      Enum.each(added, fn {topic, partition} ->
        state.topic_supervisor.start_consumer(topic, partition)
      end)
      Enum.each(removed, fn {topic, partition} ->
        state.topic_supervisor.terminate_consumer(topic, partition)
      end)
      Logger.info("PartitionManager partitions: #{Enum.count(node_old_asssignemnts)} -> #{Enum.count(node_new_assigments)} (added: #{Enum.count(added)}, removed: #{Enum.count(removed)})")
    end

    %State{state | assignments: assignments}
  end

end
