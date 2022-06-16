defmodule Eventbus.ConfigStore do
  @moduledoc """
  Configuration Store
  """
  require Logger

  @table :config_table

  def init() do
    # create ETS
    @table = :ets.new(@table, [:set, :named_table, :public,
                          read_concurrency: true, write_concurrency: true])
    :ok
  end

  def put_topics_spec(topics_spec) do
    put_store(:topics_spec, topics_spec)
    Enum.each(topics_spec, fn topic_spec ->
      put_topic_spec(topic_spec)
    end)
  end

  def put_topic_spec([topic: topic, partition_count: count] = topic_spec) do
    put_store({:topic_spec, topic}, topic_spec)
    put_store({:topic_count, topic}, count)
  end

  def validate_topic(topic) do
    cond do
      not is_nil get_store({:topic_count, topic}) ->
        {:ok, topic}
      not is_nil get_store({:topic_count, "_other"}) ->
        {:ok, "_other"}
      true ->
        {:error, "invalid topic"}
    end
  end

  def get_topics_spec() do
    get_store(:topics_spec)
  end

  def get_topic_spec(topic) do
    get_store({:topic_spec, topic})
  end

  def get_topic_count(topic) do
    get_store({:topic_count, topic})
  end

  def put_store(key, value) do
    :ets.insert(@table, {key, value})
  end

  def get_store(key) do
    case :ets.lookup(@table, key) do
      [{^key, val}] -> val
      _ ->  nil
    end
  end

end
