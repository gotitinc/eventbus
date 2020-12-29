defmodule Eventbus.TopicSupervisor do
  @moduledoc """
  Supervisor for a topic that manages a consumer for a particular partition
  """
  use DynamicSupervisor

  alias Eventbus.PartitionConsumer

  def name(topic) do
    String.to_atom("topic_#{topic}_sup")
  end

  def start_link([name, params] = arg) when is_list(arg), do: start_link(name, params)
  def start_link(name, params) do
    DynamicSupervisor.start_link(__MODULE__, params, name: name)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_restarts: 10_000)
  end

  def start_consumer(topic, partition) do
    case Process.whereis(name(topic)) do
      nil -> :not_found
      sup_pid -> start_consumer(sup_pid, topic, partition)
    end
  end

  defp start_consumer(sup, topic, partition) do
    name =  PartitionConsumer.name(topic, partition)
    DynamicSupervisor.start_child(sup, %{
      id: name,
      start: {PartitionConsumer, :start_link, [name, [topic: topic, partition: partition]]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    })
  end

  def terminate_consumer(topic, partition) do
    case Process.whereis(name(topic)) do
      nil -> :ok
      sup_pid -> terminate_consumer(sup_pid, topic, partition)
    end
  end

  defp terminate_consumer(sup, topic, partition) do
    name = PartitionConsumer.name(topic, partition)
    case Process.whereis(name) do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(sup, pid)
    end
  end
end
