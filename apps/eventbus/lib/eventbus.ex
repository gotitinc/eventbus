defmodule Eventbus do
  @moduledoc """
  Eventbus Application producs and consumes Kafka messages
  """
  alias Eventbus.{PartitionConsumer, PartitionTimer, StatsManager,
                  JobHttpPost, Utils, Redix}

  def produce(topic, key, params) do
    valid_topic = if partition_count(topic) == 0, do: "_other", else: topic
    partition = PartitionConsumer.topic_hash(key, valid_topic)
    Stats.increment(:counter, :produce_in, valid_topic, partition)

    url = Keyword.get(params, :url)
    payload = Keyword.get(params, :payload)
    job_module = Keyword.get(params, :job_module, JobHttpPost)
    max_retry = Keyword.get(params, :max_retry)
    timeout = Keyword.get(params, :timeout)

    job = job_module.init(payload, url, valid_topic, partition, max_retry, timeout)
    PartitionConsumer.post_job(valid_topic, partition, job)
    {:ok, :sent}
  end

  def produce_delayed(topic, key, params) do
    valid_topic = if partition_count(topic) == 0, do: "_other", else: topic
    partition = PartitionConsumer.topic_hash(key, valid_topic)
    Stats.increment(:counter, :produce_delay_in, valid_topic, partition)

    url = Keyword.get(params, :url)
    payload = Keyword.get(params, :payload)
    job_module = Keyword.get(params, :job_module, JobHttpPost)
    delay = Keyword.get(params, :delay, 0)
    max_retry = Keyword.get(params, :max_retry)
    timeout = Keyword.get(params, :timeout)

    job = job_module.init(payload, url, valid_topic, partition, max_retry, timeout)
    PartitionTimer.post_delayed_job(valid_topic, partition, job, Utils.now() + delay)
    {:ok, :sent}
  end

  def partition_count(topic) do
    PartitionConsumer.partition_count(topic)
  end

  def reset_events() do
    Application.get_env(:eventbus, :topics)
    |> Enum.each(fn topic_spec ->
      topic =  Keyword.get(topic_spec, :topic)
      partition_count = Keyword.get(topic_spec, :partition_count)
      for partition <- 0..(partition_count - 1) do
        PartitionTimer.reset_timers(topic, partition)
      end
    end)

    reset_counters()

    case Redix.command(:redix_pool, ["FLUSHDB"]) do
      {:ok, _} -> :ok
      error -> {:error, error}
    end

  end

  def reset_counters() do
    StatsManager.reset_all_counters()
  end

  def get_counter(:queue, topic) do
    StatsManager.get_queue(topic)
  end
  def get_counter(:timer, topic) do
    StatsManager.get_timer(topic)
  end
  def get_counter(counter, topic) do
    StatsManager.get_counter(counter, topic)
  end

  def get_latency(counter, topic) do
    StatsManager.get_latency(counter, topic)
  end

end
