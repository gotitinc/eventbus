defmodule Eventbus.Application do
  @moduledoc """
  The Eventbus Application Service.
  """
  use Application

  alias Eventbus.{TopicSupervisor, PartitionManager, StatsManager,
        ClusterManager, Tracker, Redix, Utils, ConfigStore}

  defmacro test?() do
    Mix.env() == :test
  end

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    redis_conf = Application.fetch_env!(:eventbus, :redis_url)
    environment = System.get_env("ENVIRONMENT") || "default"
    redis_url = System.get_env("REDIS_URL") || Keyword.get(redis_conf, String.to_atom(environment))
    topics_spec = (System.get_env("TOPICS") |> Utils.env_to_topics_spec)
        || Application.get_env(:eventbus, :topics, [])

    Code.ensure_loaded(Eventbus.JobHttpPost)
    Code.ensure_loaded(Eventbus.JobHttpMock)
    Code.ensure_loaded(Eventbus.Send)

    :ok = :hackney_pool.start_pool(:eb_pool, [timeout: 15_000, max_connections: 512])

    Supervisor.start_link(
    [
      {Phoenix.PubSub.Supervisor, [name: Eventbus.PubSub]},
      Redix.child_spec(redis_url)
    ]
    ++ if test?() do
      []
    else
      ConfigStore.init()
      ConfigStore.put_topics_spec(topics_spec)
      Enum.map(topics_spec, fn [topic: topic, partition_count: _] = topic_spec ->
        name = TopicSupervisor.name(topic)
        Supervisor.child_spec({TopicSupervisor, [name, topic_spec]},
          id: name,
          restart: :permanent,
          shutdown: :infinity)
      end) ++
      manager_specs()
    end , strategy: :one_for_one, name: Eventbus.Supervisor)
  end

  def manager_specs() do
    start_delay = Application.get_env(:eventbus, :start_delay, 5_000)
    [%{
      id: ClusterManager,
      start: {ClusterManager, :start_link, [ClusterManager, []]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    },
    %{
      id: Tracker,
      start: {Tracker, :start_link, [Tracker, []]},
      restart: :permanent,
      shutdown: :infinity,
      type: :worker
    },
    %{
      id: StatsManager,
      start: {StatsManager, :start_link, [StatsManager, []]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    },
    %{
      id: PartitionManager,
      start: {PartitionManager, :start_link, [PartitionManager, [start_delay: start_delay]]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }]
  end

  def start_managers() do
    for %{start: {module, :start_link, params}} <- manager_specs() do
      module.start_link(module, params)
    end
  end

end
