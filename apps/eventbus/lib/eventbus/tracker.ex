defmodule Eventbus.Tracker do
  @moduledoc """
  Tracks nodes servicing events
  """
  use Phoenix.Tracker
  alias Eventbus.{PartitionManager, StatsManager}
  require Logger

  def start_link(name, params) do
    Phoenix.Tracker.start_link(__MODULE__, params,
                               name: name,
                               broadcast_period: 1_000,
                               max_silent_periods: 4,
                               down_period: 10_000,
                               # log_level: :info,
                               pubsub_server: Eventbus.PubSub
                               )
  end

  def alive?() do
    case Process.whereis(__MODULE__) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end

  def track(pid, topic, key, meta) do
    Logger.info("Tracker track: #{inspect {pid, topic, key, meta}}")
    if alive?() do
      Phoenix.Tracker.track(__MODULE__, pid, topic, key, meta)
    else
      Logger.error("Tracker track called when Tracker is not alive")
    end
  end

  def untrack(pid, topic, key) do
    Logger.info("Tracker untrack: #{inspect {pid, topic, key}}")
    if alive?() do
      Phoenix.Tracker.untrack(__MODULE__, pid, topic, key)
    else
      Logger.error("Tracker untrack called when Tracker is not alive")
    end
  end

  def list(topic) do
    if alive?() do
      Phoenix.Tracker.list(__MODULE__, topic)
    else
      []
    end
  end

  def init(_params) do
    PartitionManager.enable_service()
    StatsManager.enable_service()
    {:ok, %{}}
  end

  def handle_diff(diff, state) do
    PartitionManager.handle_event(diff)
    StatsManager.handle_event(diff)
    {:ok, state}
  end

end
